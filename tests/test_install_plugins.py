"""Offline regression tests for the installers' command-line operations.

Run with: python -m unittest discover -s tests -v
Set PWSH to a portable PowerShell executable if it is not on PATH.
Only downloads are stubbed; installation, backups and HTML edits run normally.
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from html.parser import HTMLParser


ROOT = Path(__file__).resolve().parents[1]
PWSH = os.environ.get('PWSH') or shutil.which('pwsh')
HTML = '<html>\n<head>\n<title>Test</title>\n</head>\n<body>\nTest\n</body>\n</html>\n'


class ScriptTags(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.scripts = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        if tag == 'script':
            self.scripts.append(dict(attrs))


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='emby test ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ui = self.root / 'dashboard-ui'
        self.ui.mkdir()
        self.index = self.ui / 'index.html'
        self.index.write_text(HTML)

    def seed_plugins(self):
        for folder in ('emby-crx', 'dd-danmaku'):
            target = self.ui / folder
            target.mkdir(exist_ok=True)
            (target / 'asset.js').write_text('existing')
        for name in ('externalPlayer.js', 'home.js'):
            (self.ui / name).write_text('existing')
        self.index.write_text(HTML + '\n'.join(
            '<!-- ' + marker + ' -->' for marker in
            ('emby-crx', 'dd-danmaku', 'externalPlayer.js', 'home.js')) + '\n')

    def snapshot(self):
        return {str(p.relative_to(self.ui)): p.read_bytes()
                for p in self.ui.rglob('*') if p.is_file()}


@unittest.skipIf(os.name == 'nt', 'POSIX installer')
class ShellTests(InstallerTest):
    scripts = ('install_plugins.sh', 'install_plugins_en.sh')

    def run_shell(self, script, args=(), setup='', code=None, stdin=None):
        source = (ROOT / script).read_text()
        source = source.rstrip().removesuffix('main "$@"')
        library = self.root / 'functions.sh'
        library.write_text(source)
        env = dict(os.environ)
        if sys.platform == 'darwin':
            # Production targets Linux sed; adapt only its in-place flag locally.
            bin_dir = self.root / 'bin'
            bin_dir.mkdir(exist_ok=True)
            sed = bin_dir / 'sed'
            sed.write_text('#!/bin/sh\nif [ "$1" = "-i" ]; then shift; exec /usr/bin/sed -i "" "$@"; fi\nexec /usr/bin/sed "$@"\n')
            sed.chmod(0o755)
            env['PATH'] = str(bin_dir) + os.pathsep + env['PATH']
        prefix = '. "$1"\nLOG_FILE="$2"\nshift 2\n'
        return subprocess.run(
            ['/bin/sh', '-c', prefix + setup + '\n' + (code or 'main "$@"'),
             'test', str(library), str(self.root / 'test.log'),
             '--ui-dir', str(self.ui), *args],
            input=stdin, text=True, encoding='utf-8', errors='replace',
            capture_output=True, env=env, timeout=20)

    def test_invalid_ids_preserve_all_plugins(self):
        for script in self.scripts:
            for ids in ('typo', 'player,typo', ', ,'):
                with self.subTest(script=script, ids=ids):
                    shutil.rmtree(self.ui)
                    self.ui.mkdir()
                    self.seed_plugins()
                    before = self.snapshot()
                    result = self.run_shell(script, ('--uninstall', ids))
                    self.assertEqual(before, self.snapshot(), result.stdout + result.stderr)
                    self.assertNotEqual(0, result.returncode)

    def test_invalid_install_does_not_download_or_modify(self):
        before = self.snapshot()
        setup = 'download_file() { printf unexpected-download >&2; return 1; }'
        for script in self.scripts:
            with self.subTest(script=script):
                result = self.run_shell(script, ('--install', 'player,typo'), setup)
                self.assertEqual(before, self.snapshot(), result.stdout + result.stderr)
                self.assertNotEqual(0, result.returncode)
                self.assertNotIn('unexpected-download', result.stderr)

    def test_download_failure_exits_nonzero(self):
        for script in self.scripts:
            with self.subTest(script=script):
                result = self.run_shell(script, ('--install', 'player'),
                                        'download_file() { return 1; }')
                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertNotIn('externalPlayer.js', self.index.read_text())

    def test_install_all_download_failure_exits_nonzero(self):
        for script in self.scripts:
            with self.subTest(script=script):
                result = self.run_shell(script, ('--install-all',),
                                        'download_file() { return 1; }')
                self.assertNotEqual(0, result.returncode, result.stdout)

    def test_empty_id_exits_nonzero_without_changes(self):
        before = self.snapshot()
        for script in self.scripts:
            for option in ('--install', '--uninstall'):
                with self.subTest(script=script, option=option):
                    result = self.run_shell(script, (option, ''))
                    self.assertNotEqual(0, result.returncode, result.stdout)
                    self.assertEqual(before, self.snapshot())

    def test_install_then_uninstall_preserves_other_injections(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.index.write_text(HTML)
                installed = self.run_shell(script, ('--install', 'danmaku,swiper'),
                                           'download_file() { printf fixture > "$2"; }')
                self.assertEqual(0, installed.returncode, installed.stderr)
                removed = self.run_shell(script, ('--uninstall', 'danmaku'))
                self.assertEqual(0, removed.returncode, removed.stderr)
                html = self.index.read_text()
                self.assertEqual(['home.js'], [tag['src'] for tag in ScriptTags(html).scripts])
                self.assertIn('</head>', html)

    def test_injection_failure_exits_nonzero_and_restores_html(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.index.write_text('<!DOCTYPE html><div>Home</div>\n')
                before = self.index.read_bytes()
                result = self.run_shell(script, ('--install', 'player'),
                                        'download_file() { printf fixture > "$2"; }')
                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertEqual(before, self.index.read_bytes())

    def test_swiper_install_renames_file_and_defers_execution(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.index.write_text(HTML)
                result = self.run_shell(script, ('--install', 'swiper'),
                                        'download_file() { printf fixture > "$2"; }')
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual('fixture', (self.ui / 'home.js').read_text())
                tags = ScriptTags(self.index.read_text()).scripts
                self.assertEqual(1, len(tags))
                self.assertEqual('home.js', tags[0]['src'])
                self.assertIn('defer', tags[0])

    def test_uninstall_only_removes_requested_plugin(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.seed_plugins()
                result = self.run_shell(script, ('--uninstall', 'player'))
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertFalse((self.ui / 'externalPlayer.js').exists())
                self.assertTrue((self.ui / 'dd-danmaku/asset.js').exists())
                self.assertTrue((self.ui / 'home.js').exists())
                self.assertNotIn('externalPlayer.js', self.index.read_text())

    def test_menu_custom_path_updates_ui_and_backup_directories(self):
        for script in self.scripts:
            with self.subTest(script=script):
                code = 'configure_custom_path\ncheck_environment || exit 1\nprintf "FINAL=%s\\nBACKUP=%s\\n" "$UI_DIR" "$BACKUP_DIR"'
                result = self.run_shell(script, code=code, stdin='y\n' + str(self.ui) + '\n')
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn('FINAL=' + str(self.ui) + '\n', result.stdout)
                self.assertIn('BACKUP=' + str(self.ui / '.plugin_backups') + '\n', result.stdout)


@unittest.skipUnless(PWSH, 'PowerShell not installed; set PWSH to enable')
class PowerShellTests(InstallerTest):
    scripts = ('install_plugins.ps1', 'install_plugins_en.ps1')

    def run_powershell(self, script, args=(), fail_download=False):
        source = (ROOT / script).read_text(encoding='utf-8-sig')
        source = source.rstrip().removesuffix('Main')
        download = ('$false' if fail_download else
                    '[IO.File]::WriteAllText($out, "fixture"); $true')
        harness = self.root / 'harness.ps1'
        harness.write_text(source + '\nfunction Download-File([string]$url, [string]$out){ ' + download + ' }\nMain\n', encoding='utf-8-sig')
        return subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-File', str(harness),
                               '-UiDir', str(self.ui), *args],
                              text=True, encoding='utf-8', errors='replace',
                              capture_output=True, timeout=30)

    def test_invalid_ids_preserve_all_plugins(self):
        for script in self.scripts:
            for ids in ('typo', 'player,typo', ', ,'):
                with self.subTest(script=script, ids=ids):
                    shutil.rmtree(self.ui)
                    self.ui.mkdir()
                    self.seed_plugins()
                    before = self.snapshot()
                    result = self.run_powershell(script, ('-Uninstall', ids))
                    self.assertEqual(before, self.snapshot(), result.stdout + result.stderr)
                    self.assertNotEqual(0, result.returncode)

    def test_download_failure_exits_nonzero(self):
        for script in self.scripts:
            with self.subTest(script=script):
                result = self.run_powershell(script, ('-Install', 'player'), fail_download=True)
                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertNotIn('externalPlayer.js', self.index.read_text(encoding='utf-8-sig'))

    def test_install_all_download_failure_exits_nonzero(self):
        for script in self.scripts:
            with self.subTest(script=script):
                result = self.run_powershell(script, ('-InstallAll',), fail_download=True)
                self.assertNotEqual(0, result.returncode, result.stdout)

    def test_empty_id_exits_nonzero_without_changes(self):
        before = self.snapshot()
        for script in self.scripts:
            for option in ('-Install', '-Uninstall'):
                with self.subTest(script=script, option=option):
                    result = self.run_powershell(script, (option, ''))
                    self.assertNotEqual(0, result.returncode, result.stdout)
                    self.assertEqual(before, self.snapshot())

    def test_injection_failure_exits_nonzero_and_preserves_html(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.index.write_text('<!DOCTYPE html><div>Home</div>\n')
                before = self.index.read_bytes()
                result = self.run_powershell(script, ('-Install', 'player'))
                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertEqual(before, self.index.read_bytes())

    def test_install_then_uninstall_preserves_other_injections(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.index.write_text(HTML)
                installed = self.run_powershell(script, ('-Install', 'danmaku,swiper'))
                self.assertEqual(0, installed.returncode, installed.stderr)
                removed = self.run_powershell(script, ('-Uninstall', 'danmaku'))
                self.assertEqual(0, removed.returncode, removed.stderr)
                html = self.index.read_text(encoding='utf-8-sig')
                self.assertEqual(['home.js'], [tag['src'] for tag in ScriptTags(html).scripts])
                self.assertIn('</head>', html)

    def test_swiper_install_renames_file_and_defers_execution(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.index.write_text(HTML)
                result = self.run_powershell(script, ('-Install', 'swiper'))
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual('fixture', (self.ui / 'home.js').read_text())
                tags = ScriptTags(self.index.read_text(encoding='utf-8-sig')).scripts
                self.assertEqual(1, len(tags))
                self.assertEqual('home.js', tags[0]['src'])
                self.assertIn('defer', tags[0])

    def test_uninstall_only_removes_requested_plugin(self):
        for script in self.scripts:
            with self.subTest(script=script):
                self.seed_plugins()
                result = self.run_powershell(script, ('-Uninstall', 'player'))
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertFalse((self.ui / 'externalPlayer.js').exists())
                self.assertTrue((self.ui / 'dd-danmaku/asset.js').exists())
                self.assertTrue((self.ui / 'home.js').exists())


if __name__ == '__main__':
    unittest.main()
