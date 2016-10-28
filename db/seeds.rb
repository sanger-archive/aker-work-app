# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# Products

## Human QC Report
product_options = ProductOption.create([{
  name: "Recommendation to proceed statement",
  product_option_values: ProductOptionValue.create([ { value: 'Yes'}, { value: 'No' }])
}])

Product.create( name: "Human QC Report", product_options: product_options)

## Extraction
product_options = ProductOption.create([
  {
    name: "DNA",
    product_option_values: ProductOptionValue.create([ { value: 'Yes' }, { value: 'No' }])
  },
  {
    name: "RNA",
    product_option_values: ProductOptionValue.create([ { value: 'Yes' }, { value: 'No' }])
  }
]);
Product.create( name: "Extraction", product_options: product_options )

## Index Sequence Capture (ISC)
product_options = ProductOption.create([
  { name: "Insert Size", product_option_values: ProductOptionValue.create([ { value: 150 }, { value: 450 } ])},
  { name: "Bait Type", product_option_values: ProductOptionValue.create([ { value: "Standard Exome" }, { value: "Custom" }]) },
  { name: "Pre-pooling (plex)", product_option_values: ProductOptionValue.create([ { value: 1 }, { value: 96 } ])},
  { name: "Pooling (plex)", product_option_values: ProductOptionValue.create([ { value: 1 }, { value: 96 }]) },
  { name: "Platform", product_option_values: ProductOptionValue.create([ { value: "MiSeq" }, { value: "HiSeq 2500 Rapid" }, { value: "HiSeq 2500 Standard V4"}]) },
  { name: "Chemistry", product_option_values: ProductOptionValue.create([ { value: "V2" }, { value: "V3" }, { value: "V4" }]) },
  { name: "Read Length", product_option_values: ProductOptionValue.create([ { value: 75 }, { value: 150 }, { value: 250 }, { value: 300 }]) }
])
Product.create({ name: "Index Sequence Capture (ISC)", product_options: product_options })

## Whole Genome Sequencing (WGS)
product_options = ProductOption.create([
  { name: "Insert Size", product_option_values: ProductOptionValue.create([ { value: 150 }, { value: 450 } ])},
  { name: "Pre-pooling (plex)", product_option_values: ProductOptionValue.create([ { value: 1 }, { value: 96 } ])},
  { name: "Pooling (plex)", product_option_values: ProductOptionValue.create([ { value: 1 }, { value: 96 }]) },
  { name: "Platform", product_option_values: ProductOptionValue.create([ { value: "MiSeq" }, { value: "HiSeq 2500 Rapid" }, { value: "HiSeq 2500 Standard V4"}, { value: "HiSeqX" }]) },
  { name: "Chemistry", product_option_values: ProductOptionValue.create([ { value: "V2" }, { value: "V3" }, { value: "V4" }]) },
  { name: "Read Length", product_option_values: ProductOptionValue.create([ { value: 75 }, { value: 150 }, { value: 250 }, { value: 300 }]) }
])
Product.create({ name: "Whole Genome Sequencing (WGS)", product_options: product_options })

## Induced Pluripotent Stem Cells (IPSC)
product_options = ProductOption.create([
  { name: "Reprogramming technology", product_option_values: ProductOptionValue.create([{ value: "Sendai cytotune II"}]) },
  { name: "MOI", product_option_values: ProductOptionValue.create([{ value: "5-5-3" }]) },
  { name: "Growth Conditions", product_option_values: ProductOptionValue.create([{ value: "Feeder Free" }]) }
])
Product.create({ name: "Induced Pluripolent Stem Cells (IPS)", product_options: product_options })

## Ones where there are no options
Product.create!([
  { name: "Library" },
  { name: "GCLP Sequencing" },
  { name: "Core Exome" },
  { name: "Micro Array" },
  { name: "Fibroblast Line" }
]);