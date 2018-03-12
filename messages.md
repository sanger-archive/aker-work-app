# Messages
The following is a list of messages which can be used in Work Orders, mainly for testing purposes.

## New catalogue
The following message can be used to create a new catalogue but currently process names have to be
unique so adjust the message as required.
```json
{
   "catalogue":{
      "pipeline":"WGS",
      "url":"localhost:3400",
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
         }
      ]
   }
}
```
