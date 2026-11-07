from pathlib import Path
import argparse,json,sys
from .catalog import infer_delivery_month
from .pipeline import InputFile,build_base


def main(argv=None):
    parser=argparse.ArgumentParser(description='Prepara base privada de Contabilidade e Tributário.')
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--manifest',type=Path)
    source.add_argument('--input',type=Path)
    parser.add_argument('--delivery-month',help='Competência explícita para todas as entradas. Omita para inferir meses distintos dos caminhos/nomes.')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        if args.manifest:
            data=json.loads(args.manifest.read_text(encoding='utf-8-sig'))
            inputs=[]
            for row in data['inputs']:
                path=Path(row['path'])
                if not path.is_absolute():path=args.manifest.parent/path
                inputs.append(InputFile(path,row.get('report_id'),row.get('delivery_month',args.delivery_month),
                                        row.get('part_number'),row.get('parts_total')))
        else:
            inputs=[]
            for path in sorted(args.input.rglob('*.xlsx')):
                if path.name.startswith('~$'):continue
                month=args.delivery_month if args.delivery_month is not None else infer_delivery_month(path)
                inputs.append(InputFile(path,delivery_month=month))
        result=build_base(inputs,args.output,progress=lambda message:print(message,flush=True))
        print(json.dumps(result,ensure_ascii=False,indent=2))
        return 0
    except Exception as exc:
        print(f'Falha: {exc}',file=sys.stderr)
        return 1


if __name__=='__main__':raise SystemExit(main())
