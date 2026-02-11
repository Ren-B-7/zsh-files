#!/usr/bin/env python3
"""
System upgrade script for Arch/EndeavourOS
Converted from Bash to Python
"""

import os
import sys
import subprocess
import time
import shutil
from datetime import datetime
from pathlib import Path
import urllib.request
from concurrent.futures import ProcessPoolExecutor

# ============================================================
# GLOBAL STATE FOR PROCESS MANAGEMENT
# ============================================================

futures = []
executor = None


# ============================================================
# LOGGING FUNCTIONS
# ============================================================


def log_info(message):
    """Log informational message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"++=++ [INFO] {timestamp} ++=++ {message}")
    time.sleep(0.2)


def log_error(message):
    """Log error message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"++=++ [ERROR] {timestamp} ++=++ : {message}", file=sys.stderr)
    time.sleep(1)


def log_header(message):
    """Log section header"""
    print(f"\n========== \t {message} \t ==========\n")


def log_subheading(message):
    """Log subsection heading"""
    print(f"\n----- \t {message} \t -----\n")


# ============================================================
# UTILITY FUNCTIONS
# ============================================================


def ask_yes_no(prompt, default="N"):
    """Ask yes/no question with default"""
    while True:
        answer = input(f"++=++ {prompt} ({default}): ").strip() or default

        if answer.upper() in ["Y", "YES"]:
            return True
        if answer.upper() in ["N", "NO"]:
            return False
        log_error("Invalid input. Please enter Yes or No.")


def show_disk_space(label):
    """Get and display disk space info"""
    log_info(f"{label}:")
    try:
        stat = os.statvfs("/")
        # Calculate in GB
        total = (stat.f_blocks * stat.f_frsize) / (1024**3)
        free = (stat.f_bavail * stat.f_frsize) / (1024**3)
        used = total - free
        percent = (used / total) * 100

        print(f"  Used: {used:.1f}G / Available: {free:.1f}G ({percent:.1f}% used)")
    except Exception as e:
        log_error(f"Could not get disk space: {e}")


def command_exists(command):
    """Check if a command exists in PATH"""
    return shutil.which(command) is not None


def run_command(cmd, capture_output=False, check_error=True):
    """
    Run a command using Popen with proper resource cleanup.
    Returns (returncode, stdout, stderr)
    """
    try:
        if capture_output:
            with subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            ) as proc:
                stdout, stderr = proc.communicate()

        else:
            # When not capturing output, inherit parent's stdout/stderr
            with subprocess.Popen(cmd, stdout=None, stderr=None) as proc:
                proc.wait()
                stdout, stderr = "", ""

        if check_error and proc.returncode != 0:
            log_error(f"Command failed: {' '.join(cmd)}")
            if stderr:
                log_error(stderr)

        return proc.returncode, stdout, stderr

    except Exception as e:
        log_error(f"Command execution failed: {e}")
        return 1, "", str(e)


def backup_file(src, dst):
    """Move src -> dst safely"""
    try:
        shutil.move(src, dst)
        log_info(f"Moved {src} -> {dst}")
        return True
    except Exception as e:
        log_error(f"Failed to move {src} -> {dst}: {e}")
        return False


def set_permissions(file_path, mode=0o644):
    """Set file permissions"""
    try:
        os.chmod(file_path, mode)
        log_info(f"Permissions for {file_path} set to {oct(mode)}")
        return True
    except Exception as e:
        log_error(f"Failed to set permissions for {file_path}: {e}")
        return False


def remove_file(file_path):
    """Remove file if exists"""
    try:
        os.remove(file_path)
        log_info(f"Removed {file_path}")
        return True
    except Exception as e:
        log_error(f"Failed to remove {file_path}: {e}")
        return False


def revert_mirrorlist_backups(mirror_dir):
    """Revert mirrorlist backup files using shutil/os"""
    mirror_path = Path(mirror_dir)

    if not mirror_path.exists():
        log_error(f"Directory {mirror_dir} does not exist")
        return False

    reverted_count = 0
    for bak_file in mirror_path.glob("*.bak"):
        original = bak_file.with_suffix("")
        if backup_file(str(bak_file), str(original)):
            if set_permissions(str(original)):
                log_info(f"Reverted: {bak_file}")
                reverted_count += 1
            else:
                log_error(f"Failed to set permissions for {original}")
        else:
            log_error(f"Failed to revert {bak_file}")

    if reverted_count == 0:
        log_info(f"No .bak files found to revert in {mirror_dir}")
    else:
        log_info(f"Reverted {reverted_count} .bak file(s).")

    return True


# ============================================================
# PARALLEL TASK FUNCTIONS
# ============================================================


def run_rerank_task(name, cmd):
    """Runs a named task/command in a separate process."""
    log = []
    log.append(f"[{name}] Starting: {' '.join(cmd) if isinstance(cmd, list) else cmd}")

    ret, out, err = run_command(cmd, capture_output=True, check_error=False)

    if ret == 0:
        log.append(f"[{name}] Completed successfully")
    else:
        log.append(f"[{name}] Failed with return code {ret}")

    return {
        "name": name,
        "returncode": ret,
        "stdout": out,
        "stderr": err,
        "cmd": cmd,
        "log": "\n".join(log),
    }


def _rank_arch_mirrors(name: str, timeout: int = 5, num_mirrors: int = 15):
    """
    Download Arch Linux mirrorlist, uncomment servers, rank them,
    and save mirrorlist.pacnew. All output is logged and returned
    for printing after all tasks finish.
    """
    log = []
    orig_path = "/etc/pacman.d/mirrorlist.orig"
    pacnew_path = "/etc/pacman.d/mirrorlist.pacnew"

    # Cleanup old files
    for p in [orig_path, pacnew_path]:
        if os.path.exists(p):
            os.remove(p)

    url = "https://archlinux.org/mirrorlist/all/https/"

    try:
        log.append(f"[{name}] Downloading Arch mirrorlist…")

        req = urllib.request.Request(url, headers={"User-Agent": "ArchMirrorRanker"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = resp.read().decode("utf-8")

        # Extract active mirrors
        servers = []
        for line in data.splitlines():
            if line.startswith("#Server"):
                servers.append(line[1:].strip())
            elif line.startswith("Server"):
                servers.append(line.strip())

        # Write temporary list
        with open(orig_path, "w", encoding="utf-8") as f:
            f.write("\n".join(servers) + "\n")
        os.chmod(orig_path, 0o644)
        log.append(f"[{name}] Downloaded {len(servers)} mirror URLs")

        # Check for rankmirrors
        if not command_exists("rankmirrors"):
            raise RuntimeError("rankmirrors is not installed (pacman-contrib missing)")

        log.append(f"[{name}] Running rankmirrors -n {num_mirrors}…")

        ret, ranked, err = run_command(
            [
                "rankmirrors",
                "-m",
                str(timeout),
                "-w",
                "-p",
                "-n",
                str(num_mirrors),
                orig_path,
            ],
            capture_output=True,
            check_error=False,
        )

        if ret != 0:
            raise RuntimeError(f"rankmirrors failed: {err.strip()}")

        # Write final ranked output
        with open(pacnew_path, "w", encoding="utf-8") as f:
            f.write(ranked)
        os.chmod(pacnew_path, 0o644)

        mirror_count = len(
            [l for l in ranked.splitlines() if l.strip() and l.startswith("Server")]
        )
        log.append(f"[{name}] Completed. Ranked {mirror_count} mirrors.")

        return {
            "name": name,
            "returncode": 0,
            "stdout": ranked,
            "stderr": "",
            "log": "\n".join(log),
        }

    except Exception as e:
        log.append(f"[{name}] ERROR: {e}")
        return {
            "name": name,
            "returncode": 1,
            "stdout": "",
            "stderr": str(e),
            "log": "\n".join(log),
        }


# ============================================================
# SYSTEM UPDATE FUNCTIONS
# ============================================================


def mirrorlist():
    """Handle mirrorlist ranking for Arch and EndeavourOS"""
    global executor, futures

    log_header("Mirrorlist Management")
    if not ask_yes_no("Rerank the mirrors?", "N"):
        log_info("Mirrorlist ranking skipped.")
        return None

    if ask_yes_no("Revert mirrorlists from .bak files", "N"):
        revert_mirrorlist_backups("/etc/pacman.d")

    # Define parallel tasks
    tasks = []

    # 1. Arch mirrorlist ranking
    tasks.append(
        (
            "arch-mirrors",
            _rank_arch_mirrors,
            ("arch-mirrors", 5, 30),
        )
    )

    # 2. EndeavourOS official mirror ranking (if available)
    if command_exists("eos-rankmirrors"):
        tasks.append(
            (
                "endeavouros-mirrors",
                run_rerank_task,
                ("endeavouros-mirrors", ["eos-rankmirrors", "--hook-rank"]),
            )
        )
    else:
        log_info("eos-rankmirrors not found, skipping EndeavourOS mirrors")

    # Run all tasks in parallel
    results = []
    log_info(f"Starting {len(tasks)} mirrorlist ranking task(s) in parallel...")

    executor = ProcessPoolExecutor(max_workers=4)

    try:
        futures = [executor.submit(func, *cmd) for name, func, cmd in tasks]
        results = [future.result() for future in futures]
    except KeyboardInterrupt:
        log_error("Mirrorlist ranking interrupted!")
        raise
    finally:
        if executor:
            executor.shutdown(wait=True)

    # Show results
    log_header("Mirrorlist Ranking Results")

    for result in results:
        name = result["name"]
        print(f"\n{'='*60}")
        print(f" Task: {name}")
        print(f"{'='*60}")

        # Print task log
        if "log" in result and result["log"]:
            print(result["log"])

        # Show ranked mirrors for arch-mirrors task
        if "arch-mirrors" in name and result["returncode"] == 0:
            print("\nRanked mirrors:")
            print(result["stdout"])

        # Show stderr if present
        if result["stderr"] and result["stderr"].strip():
            print(f"\nErrors/Warnings:\n{result['stderr']}")

        # Show failure status
        if result["returncode"] != 0:
            log_error(f"{name} failed with exit code {result['returncode']}")

    # Apply .pacnew files
    log_header("Applying .pacnew files")
    files = [
        "/etc/pacman.d/mirrorlist",
        "/etc/pacman.d/endeavouros-mirrorlist",
        "/etc/pacman.d/hosts",
    ]

    for file_path in files:
        pacnew_file = f"{file_path}.pacnew"
        bak_file = f"{file_path}.bak"

        if os.path.isfile(pacnew_file):
            log_info(f"Installing {pacnew_file} → {file_path}")
            if os.path.isfile(file_path):
                backup_file(file_path, bak_file)
            if backup_file(pacnew_file, file_path):
                set_permissions(file_path)
                log_info(f"Updated {file_path}")
            else:
                log_error(f"Failed to install {pacnew_file}")

        # Cleanup old backup
        if os.path.isfile(bak_file):
            if ask_yes_no(f"Remove old backup {bak_file}?", "N"):
                remove_file(bak_file)

    log_info("All mirrorlist operations completed!")
    return None


def fwupd():
    """Update firmware using fwupdmgr"""
    log_header("Firmware update (fwupdmgr)")
    if not ask_yes_no("Update firmware with fwupdmgr", "N"):
        log_info("Firmware update skipped.")
        return None

    if ask_yes_no("Revert firmware mirrorlists from .bak files", "N"):
        revert_mirrorlist_backups("/etc/fwupd/remotes.d")

    log_subheading("Refreshing firmware databases and syncing configs")

    refresh_ret, refresh_out, refresh_err = run_command(
        ["fwupdmgr", "refresh", "--force"],
        capture_output=True,
        check_error=False,
    )

    if refresh_out:
        print(refresh_out)

    if refresh_ret != 0:
        log_error("fwupdmgr refresh failed")
        if refresh_err:
            print(refresh_err)
        return 1

    log_subheading("Syncing firmware metadata")

    sync_ret, sync_out, sync_err = run_command(
        ["fwupdmgr", "sync", "--force"],
        capture_output=True,
        check_error=False,
    )

    if sync_out:
        print(sync_out)

    if sync_ret != 0:
        log_error("fwupdmgr sync failed")
        if sync_err:
            print(sync_err)
        return 1

    log_subheading("Updating firmware devices")
    run_command(["fwupdmgr", "update"], check_error=False)
    return None


def pacman():
    """Update system packages with pacman"""
    log_header("Pacman package manager")
    log_subheading("Updating pacman database")
    run_command(["pacman", "-Syy"], check_error=False)

    log_subheading("Checking database integrity")
    _, stdout, _ = run_command(
        ["pacman", "-Dk"], capture_output=True, check_error=False
    )

    # Save to temp file
    try:
        with open("/tmp/pacman_integrity.log", "w", encoding="utf-8") as f:
            f.write(stdout)
        print(stdout)
    except:
        pass

    # Check for errors in output
    if "missing" in stdout.lower() or "not found" in stdout.lower():
        log_error("Database integrity check failed. Review /tmp/pacman_integrity.log")

        # Check for running pacman processes
        _, pacman_running, _ = run_command(
            ["pgrep", "-a", "pacman"], capture_output=True, check_error=False
        )

        if ask_yes_no("Check database lock", "Y"):
            if not pacman_running.strip():
                log_info("Removing database lock")
                run_command(
                    ["rm", "-f", "/var/lib/pacman/db.lck"],
                    check_error=False,
                )
            else:
                log_error(f"Pacman process is running: {pacman_running}")
                return 1

        if ask_yes_no("Check missing or broken database/packages", "Y"):
            log_info("Generating missing files report...")
            _, qk_output, _ = run_command(
                ["pacman", "-Qk"], capture_output=True, check_error=False
            )

            # Filter for missing files
            missing_lines = [
                line
                for line in qk_output.split("\n")
                if "missing files" in line and line.split()[3] != "0"
            ]

            if missing_lines:
                log_error("Missing files detected:")
                with open("/tmp/missing_files_report.txt", "w", encoding="utf-8") as f:
                    f.write("\n".join(missing_lines))
                print("\n".join(missing_lines))
            else:
                log_info("No missing files found.")

        if ask_yes_no("Try fixing missing dependencies", "Y"):
            run_command(["pacman", "-Syu", "--needed"], check_error=False)

        return 1

    log_info("Passed integrity check")
    log_subheading("Upgrading packages")
    run_command(["pacman", "-Suv", "--color", "auto"], check_error=False)
    return None


def yay():
    """Update AUR packages with yay"""
    log_header("yay package manager")
    if not command_exists("yay"):
        log_error("yay not installed")
        return None

    log_subheading("Upgrading AUR packages")
    run_command(["yay", "-Sua"], check_error=False)

    log_subheading("Cleaning up yay/pacman cache")
    if ask_yes_no("Remove orphaned packages?", "Y"):
        _, orphan_list, _ = run_command(
            ["pacman", "-Qdtq"], capture_output=True, check_error=False
        )

        if orphan_list.strip():
            log_info("Removing orphaned packages:")
            print(orphan_list)
            orphans = orphan_list.strip().split("\n")
            run_command(["pacman", "-Rns"] + orphans, check_error=False)
            run_command(["yay", "-Yc"], check_error=False)
            log_info("Note: /home files and configuration caches remain unaffected.")
        else:
            log_info("No orphaned packages found.")
    else:
        log_info("Skipping removal of orphaned packages.")

    show_disk_space("Before cache cleanup")
    run_command(["paccache", "-r", "-ufv"], check_error=False)
    run_command(["yay", "-Scc"], check_error=False)
    show_disk_space("After cache cleanup")


def flatpak():
    """Update flatpak packages"""
    log_header("Flatpak package manager")
    log_subheading("Updating flatpak packages")
    run_command(["flatpak", "update"], check_error=False)

    if ask_yes_no("Remove unused flatpak packages?", "Y"):
        log_info("Uninstalling unused flatpaks...")
        run_command(["flatpak", "uninstall", "--unused"], check_error=False)
    else:
        log_info("Skipping unused flatpak removal.")

    log_subheading("Checking flatpak checksums")
    if ask_yes_no("Check flatpak checksums?", "N"):
        log_info("Checking flatpaks...")
        run_command(["flatpak", "repair"], check_error=False)
    else:
        log_info("Skipping flatpaks check.")


def zinit():
    """Update zsh zinit plugins"""
    log_header("Update zsh shell")
    if not ask_yes_no("Update Zinit", "N"):
        log_info("Zinit update skipped.")
        return None

    run_command(["zinit", "self-update"])
    if ask_yes_no("Update zinit plugins", "Y"):
        run_command(["zinit", "update", "--all"])
    run_command(["zinit", "zstatus"])
    return None


def logs_journalctl():
    """Clean system logs and journalctl"""
    log_header("Cleaning logs")

    # Get log space before
    log_space_before = "0"
    try:
        ret, output, _ = run_command(
            ["du", "-sh", "/var/log"], capture_output=True, check_error=False
        )
        if ret == 0:
            log_space_before = output.split()[0]
    except:
        pass

    if ask_yes_no("Vacuum journalctl down?", "N"):
        log_info("Shrinking journalctl total size, and rotating logs")

        run_command(["journalctl", "--sync"], check_error=False)
        run_command(["journalctl", "--flush"], check_error=False)
        run_command(["journalctl", "--rotate"], check_error=False)
        run_command(["journalctl", "--vacuum-size=10M"], check_error=False)

        if command_exists("logrotate"):
            log_info("Forcing logrotate")
            run_command(
                ["logrotate", "-f", "/etc/logrotate.conf"],
                check_error=False,
            )
            log_info("Removing rotated log files")
    else:
        log_info("Skipping journalctl vacuum")

    if ask_yes_no("Shorten ACTIVE log files? (Highly invasive)", "N"):
        log_info("Stopping rsyslog")
        run_command(["systemctl", "stop", "rsyslog"], check_error=False)
        run_command(["systemctl", "stop", "systemd-journald"], check_error=False)

        log_info("Emptying current log files")
        run_command(
            [
                "find",
                "/var/log",
                "-maxdepth",
                "2",
                "-type",
                "f",
                "-name",
                "*.log",
                "-exec",
                "truncate",
                "-s",
                "0",
                "{}",
                "+",
            ],
            check_error=False,
        )

        log_info("Restarting rsyslog")
        run_command(["systemctl", "start", "rsyslog"], check_error=False)
        run_command(["systemctl", "start", "systemd-journald"], check_error=False)

        log_info("Removing rotated log files")
        run_command(
            [
                "find",
                "/var/log",
                "-type",
                "f",
                "-name",
                "*.log.*",
                "-delete",
            ],
            check_error=False,
        )
    else:
        log_info("Skipping removal of current log files")

    if ask_yes_no("Clear coredumps?", "N"):
        log_info("Cleaning coredump files...")

        # Detect init system
        if command_exists("systemctl"):
            init_system = "systemd"
        elif command_exists("sv"):
            init_system = "runit"
        else:
            init_system = "unknown"

        # Stop coredump service if systemd
        if init_system == "systemd":
            ret, output, _ = run_command(
                ["systemctl", "list-units", "--type=service"],
                capture_output=True,
                check_error=False,
            )
            if "systemd-coredump" in output:
                run_command(
                    ["systemctl", "stop", "systemd-coredump.service"],
                    check_error=False,
                )

        # Clean directories
        dirs_to_clean = [
            "/var/lib/systemd/coredump",
            "/var/crash",
            "/var/dumps",
            "/var/tmp",
            "/tmp",
        ]

        for dir_path in dirs_to_clean:
            if os.path.isdir(dir_path):
                log_info(f"Cleaning {dir_path}...")
                log_info(f"Contents of {dir_path}:")
                run_command(["ls", "-lah", dir_path], check_error=False)

                if ask_yes_no(f"Delete all contents of {dir_path}?", "N"):
                    run_command(
                        [
                            "find",
                            dir_path,
                            "-mindepth",
                            "1",
                            "-maxdepth",
                            "1",
                            "-delete",
                        ],
                        check_error=False,
                    )
                    log_info(f"Cleaned {dir_path}")
                else:
                    log_info(f"Skipped {dir_path}")

        # Restart service if systemd
        if init_system == "systemd":
            ret, output, _ = run_command(
                ["systemctl", "list-units", "--type=service"],
                capture_output=True,
                check_error=False,
            )
            if "systemd-coredump" in output:
                run_command(
                    ["systemctl", "start", "systemd-coredump.service"],
                    check_error=False,
                )

        log_info(f"Coredump cleanup complete (init system: {init_system})")
    else:
        log_info("Skipping coredump removal")

    # Sync filesystem
    try:
        os.sync()
    except:
        pass
    time.sleep(1)

    # Get log space after
    log_space_after = "0"
    try:
        ret, output, _ = run_command(
            ["du", "-sh", "/var/log"], capture_output=True, check_error=False
        )
        if ret == 0:
            log_space_after = output.split()[0]
    except:
        pass

    log_info(f"Log space: {log_space_before} -> {log_space_after}")


def final():
    """Show final summary and offer reboot"""
    log_header("Upgrade Summary")
    show_disk_space("Final disk space")
    log_info("System upgrade complete!")

    log_header("Reboot system")
    if not command_exists("reboot"):
        log_error("reboot command not found")
    else:
        if ask_yes_no("Reboot now?", "N"):
            log_info("Rebooting system in 10 seconds...")
            time.sleep(10)
            run_command(["reboot"])

    return 0


# ============================================================
# MAIN ENTRY POINT
# ============================================================


def ensure_root():
    """Ensure script is running as root"""
    if os.geteuid() != 0:
        print("Elevating privileges...")
        os.execvp("sudo", ["sudo", sys.executable] + sys.argv)


def main():
    """Main entry point"""
    global executor, futures

    try:
        log_header("Starting Full System Upgrade")
        show_disk_space("Initial disk space")

        mirrorlist()

        if command_exists("fwupdmgr"):
            fwupd()

        if command_exists("pacman"):
            pacman()
            yay()

        if command_exists("flatpak"):
            flatpak()

        if command_exists("zinit"):
            zinit()

        if command_exists("journalctl"):
            logs_journalctl()

        return final()

    except KeyboardInterrupt:
        print("\n\nInterrupted by user. Exiting...")
        if executor:
            # Cancel pending futures
            for future in futures:
                future.cancel()

            # Force terminate all running processes
            if hasattr(executor, "_processes"):
                for _, process in executor._processes.items():
                    try:
                        process.terminate()
                    except:
                        pass

            # Shutdown the executor
            executor.shutdown(wait=False, cancel_futures=True)
        return 130

    except Exception as e:
        log_error(f"Unexpected error: {e}")
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    ensure_root()
    sys.exit(main())
