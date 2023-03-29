# List of Antibiotics

The list of antibiotics in `NeoIPC-Antibiotics.csv` and the associated translation files (`NeoIPC-Antibiotics.`*`LOCALE`*`.csv`) are used to generate the list of options for selecting an antibiotic in NeoIPC.
It is based on information provided by the [WHO Collaborating Centre for Drug Statistics Methodology, Oslo, Norway](https://www.whocc.no/) and uses the ATC-code as code.
Currently the list contains a subset of the J01 (antibacterials for systemic use) branch with the combination products removed.

Since NeoIPC cares about antibiotic substances rather than the products containing antibiotic substances, the question whether the actual product might contain other active ingredients is not considered as relevant.
While keeping combination products (e.g., J01CA51 "ampicillin, combinations") as they are in the ATC index could theoretically be feasible, they tend to confuse people and decrease the quality of the collected data without increasing the resolution of information in the domain of antibiotic resistance.
Most of the time these combinations get selected where an antibiotic is used in combination with another antibiotic (combination therapy) rather than when a product containing an antibiotic and one or more other active ingredients is chosen.
