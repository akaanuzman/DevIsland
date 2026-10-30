#!/usr/bin/env python3
"""Build a dependency-free local VSIX using the standard VSIX/OPC package format."""
from pathlib import Path
import json
import sys
import zipfile
from xml.sax.saxutils import escape
source = Path(__file__).resolve().parent.parent / 'extensions' / 'vscode'
manifest = json.loads((source / 'package.json').read_text())
version = manifest['version']
target = Path(sys.argv[1]) if len(sys.argv) > 1 else source.parent.parent / 'dist' / f'dev-island-vscode-{version}.vsix'
target.parent.mkdir(parents=True, exist_ok=True)
metadata = f'''<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
<Metadata><Identity Language="en-US" Id="{escape(manifest['name'])}" Version="{version}" Publisher="{escape(manifest['publisher'])}"/>
<DisplayName>{escape(manifest['displayName'])}</DisplayName><Description xml:space="preserve">{escape(manifest['description'])}</Description>
<Tags>macOS,terminal,claude</Tags><Categories>Other</Categories><GalleryFlags>Public</GalleryFlags>
<Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="{escape(manifest['engines']['vscode'])}"/>
<Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="ui"/><Property Id="Microsoft.VisualStudio.Code.ExecutesCode" Value="true"/>
<Property Id="Microsoft.VisualStudio.Code.PreRelease" Value="false"/></Properties></Metadata>
<Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/>
<Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
<Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/README.md" Addressable="true"/></Assets></PackageManifest>'''
content_types = '''<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="json" ContentType="application/json"/><Default Extension="js" ContentType="application/javascript"/>
<Default Extension="md" ContentType="text/markdown"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>'''
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    archive.writestr('extension.vsixmanifest', metadata)
    archive.writestr('[Content_Types].xml', content_types)
    for name in ['package.json', 'extension.js', 'router.js', 'README.md']:
        archive.write(source / name, 'extension/' + name)
print(target)
