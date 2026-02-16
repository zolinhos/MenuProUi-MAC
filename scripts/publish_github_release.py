#!/usr/bin/env python3

import argparse
import base64
import json
import os
import pathlib
import subprocess
import sys
from typing import Optional
import urllib.error
import urllib.parse
import urllib.request


def get_git_credential() -> tuple[str, str]:
    proc = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        text=True,
        capture_output=True,
        check=True,
    )
    username = ""
    password = ""
    for line in proc.stdout.splitlines():
        if line.startswith("username="):
            username = line.split("=", 1)[1]
        elif line.startswith("password="):
            password = line.split("=", 1)[1]
    if not username or not password:
        raise RuntimeError("Credenciais GitHub não encontradas no git credential helper")
    return username, password


def github_request(
    url: str,
    auth: str,
    method: str = "GET",
    payload: Optional[dict] = None,
    raw_data: Optional[bytes] = None,
    content_type: Optional[str] = None,
):
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": auth,
        "X-GitHub-Api-Version": "2022-11-28",
    }

    data = raw_data
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    elif content_type:
        headers["Content-Type"] = content_type

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read()
            if not body:
                return response.status, {}
            return response.status, json.loads(body.decode())
    except urllib.error.HTTPError as err:
        err_body = err.read().decode(errors="ignore")
        if err.code == 404:
            return 404, {}
        raise RuntimeError(f"HTTP {err.code} em {url}: {err_body[:500]}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create/update GitHub release and upload assets")
    parser.add_argument("owner_repo", help="owner/repo")
    parser.add_argument("tag", help="Tag da release (ex.: v1.7.3)")
    parser.add_argument("--target", default="main", help="Branch/commit alvo")
    parser.add_argument("--name", default=None, help="Nome da release")
    parser.add_argument("--body", default=None, help="Texto da release")
    parser.add_argument("--body-file", default=None, help="Caminho para arquivo com texto da release")
    parser.add_argument("assets", nargs="+", help="Arquivos para upload")
    args = parser.parse_args()

    release_body = args.body
    if args.body_file:
        with open(args.body_file, "r", encoding="utf-8") as fp:
            release_body = fp.read()

    if not release_body:
        print("Informe --body ou --body-file", file=sys.stderr)
        return 1

    for asset in args.assets:
        if not pathlib.Path(asset).is_file():
            print(f"Arquivo não encontrado: {asset}", file=sys.stderr)
            return 1

    username, token = get_git_credential()
    auth = "Basic " + base64.b64encode(f"{username}:{token}".encode()).decode()

    owner_repo = args.owner_repo
    api = f"https://api.github.com/repos/{owner_repo}"
    upload_api = f"https://uploads.github.com/repos/{owner_repo}"
    release_name = args.name or args.tag

    status, release = github_request(f"{api}/releases/tags/{args.tag}", auth)
    if status == 404:
        status, release = github_request(
            f"{api}/releases",
            auth,
            method="POST",
            payload={
                "tag_name": args.tag,
                "target_commitish": args.target,
                "name": release_name,
                "body": release_body,
                "draft": False,
                "prerelease": False,
            },
        )
        print(f"release_created {status}")
    else:
        rid = release["id"]
        status, release = github_request(
            f"{api}/releases/{rid}",
            auth,
            method="PATCH",
            payload={
                "name": release_name,
                "body": release_body,
                "draft": False,
                "prerelease": False,
            },
        )
        print(f"release_updated {status}")

    rid = release["id"]
    _, existing_assets = github_request(f"{api}/releases/{rid}/assets", auth)
    existing_by_name = {item["name"]: item["id"] for item in existing_assets}

    for asset in args.assets:
        asset_name = os.path.basename(asset)
        if asset_name in existing_by_name:
            github_request(f"{api}/releases/assets/{existing_by_name[asset_name]}", auth, method="DELETE")
            print(f"asset_deleted {asset_name}")

    for asset in args.assets:
        asset_name = os.path.basename(asset)
        with open(asset, "rb") as fp:
            binary = fp.read()
        encoded_name = urllib.parse.quote(asset_name)
        upload_url = f"{upload_api}/releases/{rid}/assets?name={encoded_name}"
        github_request(upload_url, auth, method="POST", raw_data=binary, content_type="application/octet-stream")
        print(f"asset_uploaded {asset_name}")

    print(release.get("html_url", ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
