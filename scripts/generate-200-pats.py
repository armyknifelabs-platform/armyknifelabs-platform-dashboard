#!/usr/bin/env python3
"""
Generate 200 Personal Access Tokens for armyknife-bot GitHub user.

This script uses the GitHub REST API to create 200 PATs from the armyknife-bot
account, storing them in a .env file for backend deployment.

Requirements:
- GitHub CLI authentication (gh auth login) as armyknife-bot
- OR GitHub PAT with 'admin:personal_access_token' and 'user' scopes

Usage:
    python3 scripts/generate-200-pats.py [--batch-size 10] [--output .env.armyknife]
"""

import os
import sys
import json
import time
import argparse
import subprocess
from datetime import datetime
from pathlib import Path


def run_command(cmd: list, capture: bool = True) -> tuple[bool, str]:
    """Execute a shell command and return (success, output)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            timeout=30
        )
        return result.returncode == 0, result.stdout.strip() or result.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "Command timed out after 30 seconds"
    except Exception as e:
        return False, str(e)


def get_current_user() -> str:
    """Get the currently authenticated GitHub user."""
    success, output = run_command(["gh", "api", "user", "--jq", ".login"])
    return output if success else ""


def create_pat(token_name: str, scopes: list[str] = None) -> str | None:
    """Create a single PAT using GitHub API."""
    if scopes is None:
        scopes = ["repo", "read:user"]

    cmd = [
        "gh", "api",
        "user/personal_access_tokens",
        "-F", f"scopes={json.dumps(scopes)}",
        "-F", f"note={token_name}",
        "--jq", ".token"
    ]

    success, output = run_command(cmd)
    return output if success and output else None


def main():
    parser = argparse.ArgumentParser(
        description="Generate 200 PATs for armyknife-bot"
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=10,
        help="Number of tokens to generate per batch (default: 10)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=".env.armyknife",
        help="Output file for PAT environment variables (default: .env.armyknife)"
    )
    parser.add_argument(
        "--token",
        type=str,
        default="",
        help="GitHub PAT with admin:personal_access_token scope (or set GH_TOKEN env var)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be generated without creating tokens"
    )

    args = parser.parse_args()

    # Try to get GitHub token from argument or environment
    gh_token = args.token or os.getenv("GH_TOKEN", "")
    if gh_token:
        print(f"✅ Using provided GitHub token")
        os.environ["GH_TOKEN"] = gh_token

    # Verify authentication
    current_user = get_current_user()
    if not current_user:
        print("❌ Not authenticated with GitHub.")
        print("Options:")
        print("  1. Run: gh auth login (for interactive setup)")
        print("  2. Set GH_TOKEN environment variable with a PAT")
        print("  3. Use: --token YOUR_PAT_HERE")
        sys.exit(1)

    print(f"✅ Authenticated as: {current_user}")

    if current_user != "armyknife-bot":
        print(f"⚠️  WARNING: Authenticated as '{current_user}', not 'armyknife-bot'")
        response = input("Continue anyway? (y/n): ").lower().strip()
        if response != 'y':
            print("Aborted.")
            sys.exit(1)

    if args.dry_run:
        print("\n🔍 DRY RUN MODE - No tokens will be created")
        print(f"Would generate 200 PATs in batches of {args.batch_size}")
        print(f"Output would be saved to: {args.output}")
        return

    # Create output file
    output_path = Path(args.output)
    with open(output_path, "w") as f:
        f.write(f"# Generated armyknife-bot PATs on {datetime.now().isoformat()}\n")
        f.write(f"# User: {current_user}\n")
        f.write(f"# Total tokens: 200\n")
        f.write("# Format: ARMYKNIFE_BOT_XXX=token_value\n\n")

    print(f"\n📝 Generating 200 PATs...")
    print(f"📦 Batch size: {args.batch_size}")
    print(f"💾 Output file: {output_path.absolute()}\n")

    total_generated = 0
    total_failed = 0

    try:
        for batch_start in range(1, 201, args.batch_size):
            batch_end = min(batch_start + args.batch_size - 1, 200)
            print(f"Generating tokens {batch_start}-{batch_end}...", end="", flush=True)

            batch_tokens = []
            for i in range(batch_start, batch_end + 1):
                token_name = f"armyknife-bot-token-{i:03d}"
                token = create_pat(token_name, ["repo", "read:user"])

                if token:
                    var_name = f"ARMYKNIFE_BOT_{i:03d}"
                    batch_tokens.append((var_name, token))
                    total_generated += 1
                else:
                    total_failed += 1

                # Rate limiting: ~1 request per second
                time.sleep(1.0)

            # Write batch to file
            with open(output_path, "a") as f:
                for var_name, token in batch_tokens:
                    f.write(f"{var_name}={token}\n")

            success_count = len(batch_tokens)
            failed_count = (batch_end - batch_start + 1) - success_count
            print(f" ✓ {success_count} generated, ✗ {failed_count} failed")

            # Batch delay to avoid rate limits
            if batch_end < 200:
                print(f"  Waiting 5 seconds before next batch...")
                time.sleep(5)

        print(f"\n✅ Complete!")
        print(f"  Generated: {total_generated}/200")
        print(f"  Failed: {total_failed}/200")
        print(f"  Success rate: {(total_generated/200)*100:.1f}%")
        print(f"\n📄 Tokens saved to: {output_path.absolute()}")
        print(f"\n📋 Next steps:")
        print(f"  1. Review tokens: cat {args.output}")
        print(f"  2. Deploy to ECS secrets: aws secretsmanager update-secret ...")
        print(f"  3. Or add to .env.local for local testing")

    except KeyboardInterrupt:
        print("\n\n⏹️  Generation interrupted by user")
        print(f"Generated {total_generated} tokens before interruption")
        print(f"Partial results saved to: {output_path.absolute()}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print(f"Partial results may have been saved to: {output_path.absolute()}")
        sys.exit(1)


if __name__ == "__main__":
    main()
