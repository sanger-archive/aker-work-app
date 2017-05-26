FactoryGirl.define do
  factory :work_order_completion_message_json, class: Hash do |work_order|
    initialize_with { Hash.new.merge({
        "work_order": {
          "status": "complete",
          "work_order_id": 1,
          "comment": "Extra information about the completed work order.",

          "updated_materials": [
            {
              "id": "67047e6f-ab09-41f3-b959-62595e8bc462",
              "phenotype": "Type J",
              "gender": "female",
              "donor_id": "id1",
              "supplier_name": "id1",
              "common_name": "Mouse"
            },
          ],

          "new_materials": [
            {
              "gender": "female",
              "donor_id": "id1",
              "supplier_name": "id1",
              "common_name": "Mouse",
              "phenotype": '',
              "parents": [ "parent_id_1", "parent_id_2"],
              "container": {
                "barcode": "XYZ-123",
                "address": "B:2"
              }
            }
          ],

          "containers": [
            {
              "num_of_rows": 4,
              "num_of_cols": 6,
              "row_is_alpha": true,
              "col_is_alpha": false
            }
          ],
        }
      })
    }
  end

end