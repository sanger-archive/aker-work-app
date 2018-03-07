# Messages
The following is a list of messages which can be used in Work Orders, mainly for testing purposes.

## New catalogue
The following message can be used to create a new catalogue but currently process names have to be
unique so adjust the message as required.
```json
{
  "catalogue": {
    "id": 1,
    "pipeline": "WGS",
    "url": "dev.psd.sanger.ac.uk",
    "lims_id": "SQSC",
    "products": [{
        "id": 2,
        "name": "QC",
        "description": "Quality Control",
        "product_version": 1,
        "availability": 1,
        "requested_biomaterial_type": "blood",
        "product_class": "genotyping",
        "processes": [{
          "id": 2,
          "name": "QC",
          "stage": 1,
          "TAT": 5,
          "process_module_pairings": [{
            "from_step": null,
            "to_step": "Quantification",
            "default_path": true
          }, {
            "from_step": null,
            "to_step": "Genotyping CGP SNP",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "Genotyping DDD SNP",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "Genotyping HumGen SNP",
            "default_path": false
          }, {
            "from_step": "Quantification",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "Genotyping CGP SNP",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "Genotyping DDD SNP",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "Genotyping HumGen SNP",
            "to_step": null,
            "default_path": true
          }, {
            "from_step": "Quantification",
            "to_step": "Genotyping CGP SNP",
            "default_path": true
          }, {
            "from_step": "Quantification",
            "to_step": "Genotyping DDD SNP",
            "default_path": false
          }, {
            "from_step": "Quantification",
            "to_step": "Genotyping HumGen SNP",
            "default_path": false
          }]
        }]
      },
      {
        "id": 3,
        "name": "Library 30x Human Whole Genome",
        "description": "Library Creation",
        "product_version": 1,
        "availability": 1,
        "requested_biomaterial_type": "dna",
        "product_class": "genotyping",
        "processes": [{
          "id": 2,
          "name": "Library 30x Human Whole Genome",
          "stage": 1,
          "TAT": 8,
          "process_module_pairings": [{
            "from_step": null,
            "to_step": "PCR FREE",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "8 PCR Cycles",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "6 PCR Cycles",
            "default_path": true
          }, {
            "from_step": "PCR FREE",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "8 PCR Cycles",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "6 PCR Cycles",
            "to_step": null,
            "default_path": true
          }]
        }]
      },
      {
        "id": 4,
        "name": "30x Human Whole Genome Sequencing",
        "description": "Genome Sequencing",
        "product_version": 1,
        "availability": 1,
        "requested_biomaterial_type": "dna",
        "product_class": "genotyping",
        "processes": [{
          "id": 2,
          "name": "30x Human Whole Genome Sequencing",
          "stage": 1,
          "TAT": 8,
          "process_module_pairings": [{
            "from_step": null,
            "to_step": "NovaSeq",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "Single Plex Pooling (m=1)",
            "default_path": false
          }, {
            "from_step": null,
            "to_step": "Multiplex Pooling (m=2..96)",
            "default_path": true
          }, {
            "from_step": "NovaSeq",
            "to_step": null,
            "default_path": false
          }, {
            "from_step": "HiSeq X",
            "to_step": null,
            "default_path": true
          }, {
            "from_step": "Single Plex Pooling (m=1)",
            "to_step": "HiSeq X",
            "default_path": false
          }, {
            "from_step": "Multiplex Pooling (m=2..96)",
            "to_step": "HiSeq X",
            "default_path": true
          }]
        }]
      }]
  }
}
```
