#!/usr/bin/env python3
"""Sign nested code inside-out, preserving Sparkle's helper entitlements."""
import pathlib,subprocess,sys
app=pathlib.Path(sys.argv[1]); identity=sys.argv[2]
def sign(path, entitlements=False, preserve=False):
    args=['codesign','--force','--sign',identity]
    if identity!='-': args+=['--options','runtime','--timestamp']
    if entitlements: args+=['--entitlements','Resources/DevIsland.entitlements']
    if preserve: args+=['--preserve-metadata=entitlements']
    subprocess.run(args+[str(path)],check=True)
framework=app/'Contents/Frameworks/Sparkle.framework'
# Skip symlink aliases; only sign each physical Mach-O once.
for p in sorted(framework.rglob('*'),key=lambda p:len(p.parts),reverse=True):
    if p.is_symlink(): continue
    if p.is_file():
        with p.open('rb') as f: magic=f.read(4)
        if magic in (b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'):
            sign(p,preserve=True)
    elif p.suffix in ('.app','.xpc'): sign(p,preserve=True)
sign(framework)
sign(app/'Contents/Helpers/dev-island-bridge')
sign(app,entitlements=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
