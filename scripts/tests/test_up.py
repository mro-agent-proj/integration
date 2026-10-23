"""Startup failure handling without touching Docker, network services or user .env files."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

UP = Path(__file__).resolve().parents[1] / "up.sh"


class StartupTests(unittest.TestCase):
    def run_startup(self, failure):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            shutil.copy(UP, root / "scripts/up.sh")
            for service in ("backend", "mcp", "ai"):
                (root / service).mkdir()
            (root / "mcp/.env.mcp").touch()
            (root / "ai/.env").touch()
            (root / "backend/data/rag-dump/sdr-jasc-amm_v2").mkdir(parents=True)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            stub = f"#!{sys.executable}\n" + '''import os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
root = pathlib.Path(os.environ['STUB_ROOT'])
if name == 'docker':
    with (root / 'docker.log').open('a') as f: f.write(os.getcwd() + '\\n')
    sys.exit(0)
if name == 'sleep': sys.exit(0)
url = sys.argv[-1]
mode = os.environ['FAILURE']
if ':8080/' in url:
    p = root / 'backend-count'
    count = int(p.read_text()) + 1 if p.exists() else 1
    p.write_text(str(count))
    if mode == 'wait' or (mode == 'backend-final' and count > 1): sys.exit(22)
if mode in ('8101', '8102', '8100') and ':' + mode + '/' in url: sys.exit(22)
sys.exit(0)
'''
            for name in ("docker", "curl", "sleep"):
                executable = bin_dir / name
                executable.write_text(stub)
                executable.chmod(0o755)
            result = subprocess.run(
                ["bash", str(root / "scripts/up.sh")], capture_output=True, text=True, timeout=20,
                env={**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                     "STUB_ROOT": str(root), "FAILURE": failure},
            )
            calls = (root / "docker.log").read_text().splitlines()
            return result, calls

    def test_success(self):
        result, calls = self.run_startup("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertIn("화면:", result.stdout)

    def test_backend_timeout_stops_before_mcp(self):
        result, calls = self.run_startup("wait")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertIn("시간 초과", result.stderr)

    def test_each_final_health_failure_is_nonzero(self):
        for failure in ("backend-final", "8101", "8102", "8100"):
            with self.subTest(service=failure):
                result, _ = self.run_startup(failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("상태 확인 실패", result.stderr)
                self.assertNotIn("화면:", result.stdout)


if __name__ == "__main__":
    unittest.main()
