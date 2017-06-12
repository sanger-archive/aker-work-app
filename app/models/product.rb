class Product < ApplicationRecord
  belongs_to :catalogue

  enum availability: { suspended: 0, available: 1 }
  enum product_class: { dna_sequencing: 0, genotyping: 1, transcriptomics: 2, cell_line_creation: 3 }

end
