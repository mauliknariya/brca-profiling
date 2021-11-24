nextflow.enable.dsl=2

// Expected params
// .in - directory that contains gene signatures, with each signature
//       in a separate .txt file, listing one gene name per line
params.out = 'results'

process accuracy {
    container 'labsyspharm/brca-profiling:1.0.0'
    
    input:
    tuple path(genes), val(drug)
    file(cl)   // cell lines

    output:
    tuple val("${genes.getBaseName()}"), path('*.txt')

    script:
    carg = params.containsKey('cellLines') ? "-c $cl" : '-c /app/data/cell_list.txt'
    """
    python /app/src/random_forest.py -t estimate_accuracy \
      $carg -d $drug -g $genes -o ./ \
      -b /app/data/rnaseq_log2rpkm.csv \
      -r /app/data/grmetrics.csv \
      -p /app/data/randomforest_params.txt
    """
}

process aggregate {
    publishDir "${params.out}", mode: 'copy', saveAs: {f -> "${sig}-auc.csv"}
    
    input:  tuple val(sig), val(aucs)
    output: path('auc.csv')

    """
    echo Drug,AUC > auc.csv
    echo "$aucs" >> auc.csv
    """
}

workflow {
    cell_lines = params.containsKey('cellLines') ? file(params.cellLines) : ''
    sigs  = Channel.fromPath("${params.in}/*.txt")
    drugs = Channel.of(params.drugs).flatten()

    inputs = sigs.combine(drugs)
    accuracy(inputs, cell_lines)
        .map{sig, f -> tuple(sig, "${f.getBaseName()},${f.text}")}
        .groupTuple()
        .map{sig, aucs -> tuple(sig, aucs.join('\n'))} |
        aggregate
}