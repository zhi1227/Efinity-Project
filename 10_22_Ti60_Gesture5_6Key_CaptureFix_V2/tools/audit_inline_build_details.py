"""Read-only baseline/new timing, warnings, pin and synchronizer comparison.

The single JSON report is written under reports/inline_threshold. Original
resources are identified as historical evidence; new results must be complete.
"""
from pathlib import Path
from collections import Counter
import argparse, json, re
import xml.etree.ElementTree as ET
from inline_threshold_build import P, R, sha, stage_record, validate_sources

def text(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
def timing(path):
    value=text(path)
    setup=value.split('Setup (Max) Clock Relationship',1)[1].split('Hold (Min) Clock Relationship',1)[0]
    hold=value.split('Hold (Min) Clock Relationship',1)[1].split('NOTE:',1)[0]
    def rows(block):
        return [{'launch':m[0],'capture':m[1],'constraint_ns':float(m[2]),'slack_ns':float(m[3]),'edge':m[4]}
                for m in re.findall(r'^\s*(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\(([^)]+)\)\s*$',block,re.M)]
    result={'setup':rows(setup),'hold':rows(hold)}
    assert result['setup'] and result['hold']
    assert all(r['slack_ns']>=0 for group in result.values() for r in group)
    result['min_setup_slack_ns']=min(r['slack_ns'] for r in result['setup'])
    result['min_hold_slack_ns']=min(r['slack_ns'] for r in result['hold'])
    return result
def issues(path):
    return [dict(node.attrib) for node in ET.parse(path).getroot()]
def pinrows(path):
    return {line.split(',',1)[0]:line for line in text(path).splitlines() if re.match(r'^[A-Z]+\d+,',line)}
def warnings(path):
    whole=text(path)
    blocks=whole.split('// Efinity Synthesis Started')
    value=blocks[-1]
    lines=[line for line in value.splitlines() if re.match(r'^\[EFX-',line)]
    normalized=[]
    for line in lines:
        # Keep the actual source and warning message; ignore staging prefix
        # and line-number drift only. New/renamed logic identifiers remain.
        line=re.sub(r'\((?:[^()]*[/\\])?(rtl[/\\][^()]+|src[/\\][^()]+|vendor[/\\][^()]+|ip[/\\][^()]+|example_top\.v):\d+\)',
                    lambda m:'('+m[1].replace('\\','/')+':LINE)',line)
        normalized.append(line)
    return lines,Counter(normalized),{'synthesis_sections':max(1,len(blocks)-1),
        'raw_all_sections_warning_lines':len([line for line in whole.splitlines() if re.match(r'^\[EFX-',line)]),
        'scope':'Only final synthesis section compared; older appended sections retained as historical raw evidence'}
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('stage',type=Path)
    args=ap.parse_args();stage=args.stage.resolve()
    record=stage_record(stage);validate_sources(stage,record)
    assert record.get('build_exit_code')==0 and record.get('build_completed_utc'),'Build not finalized'
    before=R/'original_outflow';after=stage/'outflow'
    old,new=pinrows(before/'Ti60_Demo.pinout.csv'),pinrows(after/'Ti60_Demo.pinout.csv')
    changes=[{'pin':pin,'before':old.get(pin),'after':new.get(pin)} for pin in sorted(old.keys()|new.keys()) if old.get(pin)!=new.get(pin)]
    assert len(changes)==1 and changes[0]['pin']=='A9' and 'io34_button_i.N' in changes[0]['after'],changes
    buttons={}
    for signal in ('io28_button_i','io29_button_i','io35_button_i'):
        oldrows=[row for row in old.values() if signal+'.' in row]
        newrows=[row for row in new.values() if signal+'.' in row]
        assert len(oldrows)==1 and oldrows==newrows,(signal,oldrows,newrows)
        buttons[signal]=newrows[0]
    baseline_warning,bw,baseline_warning_scope=warnings(before/'Ti60_Demo.warn.log')
    current_warning,cw,current_warning_scope=warnings(after/'Ti60_Demo.warn.log')
    oldissues,newissues=issues(before/'design_issue.xml'),issues(after/'design_issue.xml')
    newcdc=text(after/'Ti60_Demo.cdc.rpt');oldcdc=text(before/'Ti60_Demo.cdc.rpt')
    assert 'No Synchronizer warnings to report.' in newcdc
    report={'status':'PASS','baseline_scope':'historical original build, hash-verified; no baseline recompilation this task',
            'stage':str(stage),'original_button_pin_rows_unchanged':buttons,'all_pin_row_changes':changes,
            'timing':{'historical_original':timing(before/'Ti60_Demo.timing.rpt'),'new':timing(after/'Ti60_Demo.timing.rpt')},
            'synthesis_warnings':{'original_count':len(baseline_warning),'new_count':len(current_warning),
                'original_scope':baseline_warning_scope,'new_scope':current_warning_scope,
                'added_or_changed':[{'count':count,'warning':message} for message,count in (cw-bw).items()],
                'removed_or_changed':[{'count':count,'warning':message} for message,count in (bw-cw).items()],
                'normalization':'Staging prefix and source line numbers only; logic identifiers retained'},
            'interface_issues':{'original':oldissues,'new':newissues,
                'new_or_changed':[v for v in newissues if v not in oldissues],
                'removed_or_changed':[v for v in oldissues if v not in newissues],
                'board_scope':'Interface generation passed; HSIO GPIO/LVDS proximity warnings still require physical noise-coupling observation'},
            'synchronizer_report':{'identical_to_original':oldcdc==newcdc,'new':newcdc,
                'scope':'Efinity synchronizer report, not formal CDC/MTBF certification'},
            'input_source_count':len(record['production_inputs']),
            'evidence_sha256':{str((after/name).relative_to(stage)):sha(after/name) for name in
                ('Ti60_Demo.timing.rpt','Ti60_Demo.warn.log','Ti60_Demo.pinout.csv','design_issue.xml','Ti60_Demo.cdc.rpt')},
            'hardware_programmed':False}
    output=R/'build_detail_audit.json';output.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'status':'PASS','report':str(output),'timing':report['timing']['new'],
                      'warning_counts':[len(baseline_warning),len(current_warning)],
                      'new_interface_issues':report['interface_issues']['new_or_changed']},indent=2))
if __name__=='__main__':main()
