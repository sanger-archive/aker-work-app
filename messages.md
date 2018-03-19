# Messages
The following is a list of messages which can be used in Work Orders, mainly for testing purposes.

## New catalogue
The following message can be used to create a new catalogue but currently process names have to be
unique so adjust the message as required.
```json
{
   "catalogue":{
      "pipeline":"WGS",
      "url":"http://localhost:3400",
      "lims_id":"SQSC",
      "processes":[
         {
            "uuid":"5ff66b00-d5a5-4014-9049-801f73bfaff2",
            "name":"QC",
            "TAT":5,
            "process_module_pairings":[
               {
                  "from_step":null,
                  "to_step":"Quantification",
                  "default_path":true
               },
               {
                  "from_step":null,
                  "to_step":"Genotyping CGP SNP",
                  "default_path":false
               },
               {
                  "from_step":null,
                  "to_step":"Genotyping DDD SNP",
                  "default_path":false
               },
               {
                  "from_step":null,
                  "to_step":"Genotyping HumGen SNP",
                  "default_path":false
               },
               {
                  "from_step":"Quantification",
                  "to_step":null,
                  "default_path":false
               },
               {
                  "from_step":"Genotyping CGP SNP",
                  "to_step":null,
                  "default_path":false
               },
               {
                  "from_step":"Genotyping DDD SNP",
                  "to_step":null,
                  "default_path":false
               },
               {
                  "from_step":"Genotyping HumGen SNP",
                  "to_step":null,
                  "default_path":true
               },
               {
                  "from_step":"Quantification",
                  "to_step":"Genotyping CGP SNP",
                  "default_path":false
               },
               {
                  "from_step":"Quantification",
                  "to_step":"Genotyping DDD SNP",
                  "default_path":false
               },
               {
                  "from_step":"Quantification",
                  "to_step":"Genotyping HumGen SNP",
                  "default_path":true
               }
            ]
         },
         {
            "uuid":"d96f64c9-46d9-46b9-bb7f-939256839147",
            "name":"PROCESS 2",
            "TAT":11,
            "process_module_pairings":[
               {
                  "from_step":null,
                  "to_step":"Alpha",
                  "default_path":true
               },
               {
                  "from_step":null,
                  "to_step":"Beta",
                  "default_path":false
               },
               {
                  "from_step":null,
                  "to_step":"Gamma",
                  "default_path":false
               },
               {
                  "from_step":null,
                  "to_step":"Delta",
                  "default_path":false
               },
               {
                  "from_step":"Alpha",
                  "to_step":null,
                  "default_path":false
               },
               {
                  "from_step":"Beta",
                  "to_step":null,
                  "default_path":false
               },
               {
                  "from_step":"Gamma",
                  "to_step":null,
                  "default_path":false
               },
               {
                  "from_step":"Delta",
                  "to_step":null,
                  "default_path":true
               },
               {
                  "from_step":"Alpha",
                  "to_step":"Beta",
                  "default_path":false
               },
               {
                  "from_step":"Alpha",
                  "to_step":"Gamma",
                  "default_path":false
               },
               {
                  "from_step":"Alpha",
                  "to_step":"Delta",
                  "default_path":true
               }
            ]
         },
         {
            "uuid":"a1773c00-b88e-46e7-a083-b93427718e05",
            "name": "Library 30x Human Whole Genome",
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
               }
            ]
         },
         {
            "uuid": "04ccadb6-121b-4a23-a789-6f310e7f3351",
            "name": "30x Human Whole Genome Sequencing",
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
               }
            ]
         }
      ],
      "products":[
         {
            "uuid":"eca9d7f9-7dd3-46e4-9e99-75031b8e5d43",
            "name":"QC",
            "description":"Lorem Ipsum",
            "product_version":1,
            "availability":1,
            "requested_biomaterial_type":"blood",
            "product_class":"genotyping",
            "process_uuids":[
               "5ff66b00-d5a5-4014-9049-801f73bfaff2",
               "d96f64c9-46d9-46b9-bb7f-939256839147"
            ]
         },
         {
            "uuid":"13c5f330-b58d-4bb0-9f3d-f6e39b4f69c3",
            "name":"Library 30x Human Whole Genome",
            "description":"Library Creation",
            "product_version":1,
            "availability":1,
            "requested_biomaterial_type":"dna",
            "product_class":"genotyping",
            "process_uuids":[
               "a1773c00-b88e-46e7-a083-b93427718e05"
            ]
         },
         {
            "uuid":"a5c08d1e-367c-40e1-9cff-a18dc7dcfb05",
            "name":"30x Human Whole Genome Sequencing",
            "description":"Genome Sequencing",
            "product_version":1,
            "availability":1,
            "requested_biomaterial_type":"dna",
            "product_class":"genotyping",
            "process_uuids":[
               "04ccadb6-121b-4a23-a789-6f310e7f3351"
            ]
         }
      ]
   }
}
```
