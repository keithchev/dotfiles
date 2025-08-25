# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "boto3",
#     "pyyaml",
#     "click",
#     "pytz",
# ]
# ///
"""
This script provides a simple interface to start and stop EC2 instances by alias.

It uses ~/.aws-instances.yaml to map manually-defined aliases to instance IDs.

It was largely written by Claude.
The shh config parser in particular is unreviewed but appears to work.
"""

import click
import pathlib
import shutil
import time
import datetime
from typing import Optional, Tuple
import pytz

import boto3
import yaml
from botocore.exceptions import ClientError


def format_timestamp_pst(timestamp) -> str:
    """Format a timestamp to PST in the style '2024-07-23 4:31PM'"""
    if timestamp is None:
        return "N/A"
    
    # Convert to PST timezone
    pst = pytz.timezone('US/Pacific')
    pst_time = timestamp.astimezone(pst)
    
    # Format as requested: 2024-07-23 4:31PM
    return pst_time.strftime("%Y-%m-%d %-I:%M%p")


def load_instances_config() -> dict:
    """
    Load and parse the ~/.aws-instances.yaml configuration file.

    Returns:
        Dictionary with instances mapping, or empty dict if file doesn't exist
        or has no instances section.

    Raises:
        FileNotFoundError: If config file doesn't exist
        ValueError: If YAML is invalid
    """
    config_path = pathlib.Path.home() / ".aws-instances.yaml"

    if not config_path.exists():
        raise FileNotFoundError(
            f"Instance alias config not found at {config_path}. "
            f"Create a YAML file with format: instances:\n  alias: i-instanceid"
        )

    try:
        with config_path.open("r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML in {config_path}: {e}")

    return config.get("instances", {})


def get_instance_id_by_alias(alias: str) -> str:
    """
    Look up instance ID by alias from ~/.aws-instances.yaml

    Expected YAML format:
    instances:
      alias-name: i-1234567890abcdef0
      another-alias: i-abcdef1234567890
    """
    instances = load_instances_config()

    if alias not in instances:
        available = ", ".join(instances.keys())
        raise ValueError(f"Alias '{alias}' not found. Available aliases: {available}")

    instance_id = instances[alias]
    if not instance_id.startswith("i-"):
        raise ValueError(
            f"Invalid instance ID '{instance_id}' for alias '{alias}'. "
            f"Instance IDs must start with 'i-'."
        )

    return instance_id


def start_instance_and_get_ip(
    instance_id_or_alias: str,
    profile: Optional[str],
    region: Optional[str],
    timeout: int = 300,
) -> Tuple[str, str]:
    """
    Start the instance (no-op if already running), wait for 'running',
    then poll until a PublicIpAddress is available.
    Returns (state, public_ip).
    """
    session_kwargs = {}
    if profile:
        session_kwargs["profile_name"] = profile
    session = boto3.Session(**session_kwargs)

    ec2 = session.client("ec2", region_name=region)

    instance_id: str
    if instance_id_or_alias.startswith("i-"):
        instance_id = instance_id_or_alias
    else:
        instance_id = get_instance_id_by_alias(instance_id_or_alias)

    # Try to start; if already running, AWS won't error.
    try:
        print(f"Starting instance {instance_id} ...")
        ec2.start_instances(InstanceIds=[instance_id])
    except ClientError as e:
        # If it's already running or pending, continue; else raise
        code = e.response.get("Error", {}).get("Code")
        if code not in {"IncorrectInstanceState"}:
            raise

    print("Waiting for instance to enter 'running' state ...")
    waiter = ec2.get_waiter("instance_running")
    try:
        waiter.wait(
            InstanceIds=[instance_id],
            WaiterConfig={"Delay": 5, "MaxAttempts": max(1, timeout // 5)},
        )
    except Exception as e:
        raise RuntimeError(f"Timed out waiting for instance to run: {e}")

    print("Polling for Public IP ...")
    ip = None
    deadline = time.time() + timeout
    while time.time() < deadline:
        resp = ec2.describe_instances(InstanceIds=[instance_id])
        reservations = resp.get("Reservations", [])
        if reservations and reservations[0]["Instances"]:
            inst = reservations[0]["Instances"][0]
            state = inst["State"]["Name"]
            ip = inst.get("PublicIpAddress")
            if ip:
                print(f"Public IP acquired: {ip}")
                return state, ip
        time.sleep(3)

    raise RuntimeError(
        "Timed out waiting for PublicIpAddress. "
        "Ensure the instance has an associated public IP (check subnet/ENI settings)."
    )


def stop_instance(
    instance_id_or_alias: str,
    profile: Optional[str],
    region: Optional[str],
    timeout: int = 300,
) -> str:
    """
    Stop the instance (no-op if already stopped), wait for 'stopped'.
    Returns the final state.
    """
    session_kwargs = {}
    if profile:
        session_kwargs["profile_name"] = profile
    session = boto3.Session(**session_kwargs)

    ec2 = session.client("ec2", region_name=region)

    instance_id: str
    if instance_id_or_alias.startswith("i-"):
        instance_id = instance_id_or_alias
    else:
        instance_id = get_instance_id_by_alias(instance_id_or_alias)

    # Try to stop; if already stopped, AWS won't error.
    try:
        print(f"Stopping instance {instance_id} ...")
        ec2.stop_instances(InstanceIds=[instance_id])
    except ClientError as e:
        # If it's already stopped or stopping, continue; else raise
        code = e.response.get("Error", {}).get("Code")
        if code not in {"IncorrectInstanceState"}:
            raise

    print("Waiting for instance to enter 'stopped' state ...")
    waiter = ec2.get_waiter("instance_stopped")
    try:
        waiter.wait(
            InstanceIds=[instance_id],
            WaiterConfig={"Delay": 5, "MaxAttempts": max(1, timeout // 5)},
        )
    except Exception as e:
        raise RuntimeError(f"Timed out waiting for instance to stop: {e}")

    # Get final state
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    reservations = resp.get("Reservations", [])
    if reservations and reservations[0]["Instances"]:
        state = reservations[0]["Instances"][0]["State"]["Name"]
        print(f"Instance stopped successfully. Final state: {state}")
        return state

    raise RuntimeError("Could not determine instance state after stopping")


def _is_host_line(line: str) -> bool:
    s = line.strip()
    # Treat lines starting with "Host " (case-insensitive) as section starts; ignore comments
    return s.lower().startswith("host ") and not s.startswith("#")


def _host_matches(line: str, host_alias: str) -> bool:
    # Host keith-msa-server OR "Host keith-msa-server other"
    parts = line.strip().split()
    if len(parts) >= 2 and parts[0].lower() == "host":
        aliases = parts[1:]
        return host_alias in aliases
    return False


def update_ssh_config_host(
    host_alias: str, new_ip: str, ssh_config_path: Optional[pathlib.Path] = None
) -> None:
    """
    Update (or insert) HostName under the specified Host alias in ~/.ssh/config.
    Makes a timestamped backup first.
    """
    if ssh_config_path is None:
        ssh_config_path = pathlib.Path.home() / ".ssh" / "config"

    ssh_config_path.parent.mkdir(parents=True, exist_ok=True)

    original = ""
    if ssh_config_path.exists():
        original = ssh_config_path.read_text(encoding="utf-8")

    backup_path = ssh_config_path.with_suffix(
        ssh_config_path.suffix
        + f".bak-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}"
    )
    if ssh_config_path.exists():
        shutil.copy2(ssh_config_path, backup_path)
        print(f"Backed up SSH config to {backup_path}")

    lines = original.splitlines() if original else []
    changed = False

    # Minimal SSH config "parser"
    out_lines = []
    in_target = False
    saw_hostname_in_section = False

    i = 0
    while i < len(lines):
        line = lines[i]
        if _is_host_line(line):
            # Leaving previous section: if we were in target and didn't see HostName, insert it before this new section
            if in_target and not saw_hostname_in_section:
                out_lines.append(f"    HostName {new_ip}")
                changed = True
            # Enter new section?
            in_target = _host_matches(line, host_alias)
            saw_hostname_in_section = False
            out_lines.append(line)
            i += 1
            continue

        if in_target:
            stripped = line.lstrip()
            key_lower = stripped.split(None, 1)[0].lower() if stripped else ""
            if key_lower == "hostname":
                # Replace hostname line
                indent = line[: len(line) - len(line.lstrip())]
                out_lines.append(f"{indent}HostName {new_ip}")
                saw_hostname_in_section = True
                changed = True
            else:
                out_lines.append(line)
        else:
            out_lines.append(line)
        i += 1

    # If file had no target host section at all, append one
    if not any(
        _is_host_line(line) and _host_matches(line, host_alias) for line in lines
    ):
        if out_lines and out_lines[-1].strip():
            out_lines.append("")  # ensure blank line before new section
        out_lines.append(f"Host {host_alias}")
        out_lines.append(f"    HostName {new_ip}")
        changed = True
        print(f"Added new Host section for '{host_alias}'.")

    # If we ended inside the target section and never saw HostName, append it
    if in_target and not saw_hostname_in_section:
        out_lines.append(f"    HostName {new_ip}")
        changed = True

    if changed:
        ssh_config_path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
        print(
            f"Updated {ssh_config_path} with HostName {new_ip} for Host {host_alias}."
        )
    else:
        print("No changes needed to SSH config (HostName already up to date).")


@click.group()
def cli():
    """Manage EC2 instances by alias or instance ID."""
    pass


@cli.command()
@click.argument("instance")
@click.option(
    "--host-alias",
    help="Host alias in ~/.ssh/config to update (if different from instance alias)",
)
@click.option("--profile", help="AWS profile name")
@click.option("--region", help="AWS region (e.g., us-west-2)")
@click.option("--timeout", default=60, help="Timeout in seconds")
def start(instance, host_alias, profile, region, timeout):
    """Start an EC2 instance and update SSH config."""
    state, ip = start_instance_and_get_ip(
        instance_id_or_alias=instance,
        profile=profile,
        region=region,
        timeout=timeout,
    )

    print(f"Instance state: {state}")
    update_ssh_config_host(host_alias or instance, ip)


@cli.command()
@click.argument("instance")
@click.option("--profile", help="AWS profile name")
@click.option("--region", help="AWS region (e.g., us-west-2)")
@click.option("--timeout", default=300, help="Timeout in seconds")
def stop(instance, profile, region, timeout):
    """Stop an EC2 instance."""
    state = stop_instance(
        instance_id_or_alias=instance,
        profile=profile,
        region=region,
        timeout=timeout,
    )
    print(f"Final instance state: {state}")


@cli.command()
def list():
    """List all instance aliases from the config file."""
    try:
        instances = load_instances_config()
    except FileNotFoundError:
        config_path = pathlib.Path.home() / ".aws-instances.yaml"
        click.echo(f"Config file not found at {config_path}")
        click.echo("Create a YAML file with format:")
        click.echo("instances:")
        click.echo("  alias-name: i-1234567890abcdef0")
        return
    except ValueError as e:
        click.echo(f"Error reading config: {e}")
        return

    if not instances:
        click.echo("No instances found in config file")
        return

    click.echo("Available instance aliases:")
    for alias, instance_id in instances.items():
        click.echo(f"  {alias} -> {instance_id}")


@cli.command()
@click.argument("instance", required=False)
@click.option("--profile", help="AWS profile name")
@click.option("--region", help="AWS region (e.g., us-west-2)")
def status(instance, profile, region):
    """Show instance status. If no instance specified, shows status for all aliases."""
    session_kwargs = {}
    if profile:
        session_kwargs["profile_name"] = profile
    session = boto3.Session(**session_kwargs)

    ec2 = session.client("ec2", region_name=region)

    instance_ids = []

    if instance:
        # Single instance specified
        if instance.startswith("i-"):
            instance_ids = [instance]
        else:
            try:
                instance_id = get_instance_id_by_alias(instance)
                instance_ids = [instance_id]
            except (FileNotFoundError, ValueError) as e:
                click.echo(f"Error: {e}")
                return
    else:
        # No instance specified - get all from config
        try:
            instances_config = load_instances_config()
        except FileNotFoundError:
            click.echo("Config file not found and no instance specified")
            return
        except ValueError as e:
            click.echo(f"Error reading config: {e}")
            return

        if not instances_config:
            click.echo("No instances found in config file")
            return

        instance_ids = list(instances_config.values())

    describe_response = ec2.describe_instances(InstanceIds=instance_ids)
    status_response = ec2.describe_instance_status(
        InstanceIds=instance_ids, IncludeAllInstances=True
    )

    # Create lookup for status info
    status_lookup = {
        s["InstanceId"]: s for s in status_response.get("InstanceStatuses", [])
    }

    for reservation in describe_response.get("Reservations", []):
        for inst in reservation.get("Instances", []):
            instance_id = inst["InstanceId"]
            state = inst["State"]["Name"]
            instance_type = inst["InstanceType"]
            public_ip = inst.get("PublicIpAddress", "N/A")
            private_ip = inst.get("PrivateIpAddress", "N/A")
            
            # Format launch time in PST
            launch_time = format_timestamp_pst(inst.get("LaunchTime"))
            
            # Get state transition time for all states
            state_transition_time = format_timestamp_pst(inst["State"].get("TransitionTime"))

            # Get the region from the placement or use the passed region parameter
            instance_region = inst.get("Placement", {}).get("AvailabilityZone", "")
            if instance_region:
                # Extract region from AZ (e.g., "us-west-2a" -> "us-west-2")
                instance_region = instance_region[:-1]
            else:
                instance_region = region or "N/A"

            # Find alias for this instance
            alias = "N/A"
            if not instance or not instance.startswith("i-"):
                try:
                    instances_config = load_instances_config()
                    for a, iid in instances_config.items():
                        if iid == instance_id:
                            alias = a
                            break
                except (FileNotFoundError, ValueError):
                    pass

            click.echo(f"Instance: {instance_id} ({alias})")
            click.echo(f"  State: {state}")
            click.echo(f"  Type: {instance_type}")
            click.echo(f"  Region: {instance_region}")
            click.echo(f"  Launch Time: {launch_time}")
            
            # Show state transition time with appropriate label
            # Use transition time if available, otherwise fall back to launch time for running instances
            time_to_display = state_transition_time
            if (not state_transition_time or state_transition_time == "N/A") and state == "running":
                time_to_display = launch_time
            
            if time_to_display and time_to_display != "N/A":
                if state == "running":
                    click.echo(f"  Running Since: {time_to_display}")
                elif state in ["stopped", "stopping"]:
                    click.echo(f"  Stopped Time: {time_to_display}")
                elif state in ["terminated", "terminating"]:
                    click.echo(f"  Terminated Time: {time_to_display}")
                elif state == "pending":
                    click.echo(f"  Pending Since: {time_to_display}")
                else:
                    click.echo(f"  State Changed: {time_to_display}")
            
            click.echo(f"  Public IP: {public_ip}")
            click.echo(f"  Private IP: {private_ip}")

            # Show detailed status if available
            if instance_id in status_lookup:
                status_info = status_lookup[instance_id]
                instance_status = status_info.get("InstanceStatus", {}).get(
                    "Status", "N/A"
                )
                system_status = status_info.get("SystemStatus", {}).get("Status", "N/A")
                click.echo(f"  Instance Status: {instance_status}")
                click.echo(f"  System Status: {system_status}")

                # Show any status details/events
                instance_events = status_info.get("InstanceStatus", {}).get(
                    "Details", []
                )
                system_events = status_info.get("SystemStatus", {}).get("Details", [])

                if instance_events:
                    click.echo("  Instance Status Details:")
                    for detail in instance_events:
                        click.echo(
                            f"    {detail.get('Name', 'N/A')}: {detail.get('Status', 'N/A')}"
                        )

                if system_events:
                    click.echo("  System Status Details:")
                    for detail in system_events:
                        click.echo(
                            f"    {detail.get('Name', 'N/A')}: {detail.get('Status', 'N/A')}"
                        )
            else:
                click.echo("  Instance Status: N/A")
                click.echo("  System Status: N/A")

            click.echo("")


if __name__ == "__main__":
    cli()
