# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "boto3",
#     "click",
# ]
# ///
import os
import pathlib

import boto3
import click


CACHE_DIR = pathlib.Path.home() / "s3-cache"


def parse_s3_path(path: str) -> tuple[str, str]:
    """Parse an S3 path into (bucket, prefix). Accepts 's3://bucket/prefix' or 'bucket/prefix'."""
    if path.startswith("s3://"):
        path = path[5:]
    path = path.strip("/")
    parts = path.split("/", 1)
    bucket = parts[0]
    prefix = parts[1] if len(parts) > 1 else ""
    return bucket, prefix


def format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024**2:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024**3:
        return f"{size_bytes / 1024**2:.1f} MB"
    else:
        return f"{size_bytes / 1024**3:.2f} GB"


@click.command()
@click.argument("s3_path")
@click.option("--profile", help="AWS profile name")
@click.option("--region", help="AWS region (e.g., us-west-2)")
@click.option("--dry-run", is_flag=True, help="List first 10 files and total size without downloading")
def fetch(s3_path, profile, region, dry_run):
    """Download an S3 prefix to ~/s3-cache/<bucket>/<prefix>/."""
    bucket, prefix = parse_s3_path(s3_path)
    if not prefix:
        click.echo("Error: must specify a prefix (not just a bucket)")
        raise SystemExit(1)

    session_kwargs = {}
    if profile:
        session_kwargs["profile_name"] = profile
    session = boto3.Session(**session_kwargs)
    s3 = session.client("s3", region_name=region)

    local_root = CACHE_DIR / bucket / prefix

    paginator = s3.get_paginator("list_objects_v2")
    list_prefix = prefix if prefix.endswith("/") else prefix + "/"

    if dry_run:
        total_size = 0
        total_files = 0
        for page in paginator.paginate(Bucket=bucket, Prefix=list_prefix):
            for obj in page.get("Contents", []):
                if obj["Key"].endswith("/"):
                    continue
                total_files += 1
                total_size += obj["Size"]
                if total_files <= 10:
                    click.echo(f"  {obj['Key']} ({format_size(obj['Size'])})")
        if total_files == 0:
            click.echo(f"No objects found under s3://{bucket}/{list_prefix}")
        else:
            if total_files > 10:
                click.echo(f"  ... and {total_files - 10} more file(s)")
            click.echo(f"\nTotal: {total_files} file(s), {format_size(total_size)}")
            click.echo(f"Would download to: {local_root}")
        return

    local_root.mkdir(parents=True, exist_ok=True)

    total = 0
    for page in paginator.paginate(Bucket=bucket, Prefix=list_prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue

            rel_path = key[len(prefix.rstrip("/")) + 1:]
            local_path = local_root / rel_path
            local_path.parent.mkdir(parents=True, exist_ok=True)

            click.echo(f"  downloading {key} ({format_size(obj['Size'])})")
            s3.download_file(bucket, key, str(local_path))
            total += 1

    if total == 0:
        click.echo(f"No objects found under s3://{bucket}/{list_prefix}")
    else:
        click.echo(f"\nDownloaded {total} file(s) to {local_root}")


if __name__ == "__main__":
    fetch()
