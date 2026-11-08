"""Guard the local RPM preparation against silent upstream packaging changes."""

from pathlib import Path
import runpy
import unittest


TOOL = runpy.run_path(str(Path(__file__).parents[1] / 'roles/niri/files/build-noctalia-fade.py'))
SPEC = '''Name: noctalia
Version: 5.4.1
Release: %autorelease
Source: https://example.invalid/noctalia-%{version}.tar.gz
BuildRequires: meson
%description
Shell
%prep
%autosetup
# Fedora's own source adjustments stay here.
%conf
%meson -Dtests=enabled
%build
%meson_build
%check
%meson_test
%files
%{_bindir}/noctalia
'''


class SpecPreparationTests(unittest.TestCase):
    def test_fedora_build_tests_and_inventory_are_preserved(self):
        changed = TOOL['patched_spec'](SPEC, '1.fc45.graphite.0123456789ab')
        self.assertIn('Release:        1.fc45.graphite.0123456789ab', changed)
        self.assertIn('BuildRequires: meson', changed)
        for section in ['%conf\n%meson -Dtests=enabled', '%check\n%meson_test', '%files\n%{_bindir}/noctalia']:
            self.assertIn(section, changed)
        self.assertLess(changed.index('%autosetup'), changed.index('git apply --check'))
        self.assertLess(changed.index('git apply %{SOURCE9999}'), changed.index("grep -Fq 'm_sceneRoot"))
        self.assertIn('Source9998:      graphite-quiet-selection.patch', changed)
        self.assertLess(changed.index('git apply %{SOURCE9998}'), changed.index("grep -Fq 'inline Button::ButtonPalette quietPalette("))
        self.assertIn('git apply --check %{SOURCE9997}', changed)
        self.assertIn("grep -Fq 'deferredCalls.emplace_back([this]'", changed)
        self.assertIn("# Fedora's own source adjustments stay here.", changed)

    def test_changed_upstream_prep_requires_review(self):
        for changed in [SPEC.replace('%autosetup', '%setup'), SPEC + '\n%autosetup\n']:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                TOOL['patched_spec'](changed, '1.fc45.graphite.0123456789ab')

    def test_new_source_layout_or_patch_number_collision_requires_review(self):
        for extra in ['Source1: additional-asset.tar.gz\n', 'Source9999: existing.patch\n', 'Source9998: existing.patch\n', 'Source9997: existing.patch\n']:
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                TOOL['patched_spec'](extra + SPEC, '1.fc45.graphite.0123456789ab')

    def test_missing_or_duplicate_release_is_rejected(self):
        for changed in [SPEC.replace('Release:', '# Release:'), 'Release: 2\n' + SPEC]:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                TOOL['patched_spec'](changed, '1.fc45.graphite.0123456789ab')


if __name__ == '__main__':
    unittest.main()
