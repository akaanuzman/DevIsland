#!/usr/bin/env python3
"""Reject feed rollback, unsigned/misdirected enclosures and lost historical entries."""
import pathlib,sys,xml.etree.ElementTree as ET
from version import metadata
S='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
def items(path):
    if not pathlib.Path(path).exists(): return []
    return ET.parse(path).findall('./channel/item')
def validate(new,old,version,build):
    rows=items(new); previous=items(old)
    ids=lambda entries:{(r.findtext(S+'version'), r.find('enclosure').get('url')) for r in entries}
    if not ids(previous)<=ids(rows): raise ValueError('Historical feed entries were lost')
    found=[]
    for row in rows:
        enclosure=row.find('enclosure')
        number=row.findtext(S+'version') or enclosure.get(S+'version')
        display=row.findtext(S+'shortVersionString') or enclosure.get(S+'shortVersionString')
        if number==str(build): found.append((row,enclosure,display))
    if len(found)!=1: raise ValueError('Expected exactly one new build')
    row,enclosure,display=found[0]
    expected=f'https://github.com/akaanuzman/DevIsland-releases/releases/download/v{version}/Dev-Island-{version}-arm64.dmg'
    if display!=version or enclosure.get('url')!=expected: raise ValueError('Wrong version or release URL')
    if not enclosure.get(S+'edSignature') or int(enclosure.get('length','0'))<=0: raise ValueError('Missing signature/size')
    beta=row.findtext(S+'channel')
    if beta!=('beta' if '-beta.' in version else None): raise ValueError('Wrong release channel')
    for prior in previous:
        prior_enclosure=prior.find('enclosure')
        n=prior.findtext(S+'version') or prior_enclosure.get(S+'version')
        if int(n)>=build: raise ValueError('Build must increase across stable AND beta releases')
    return len(rows)
if __name__=='__main__':
    v=metadata();print('Validated',validate(sys.argv[1],sys.argv[2],v['version'],v['build']),'feed entries')
