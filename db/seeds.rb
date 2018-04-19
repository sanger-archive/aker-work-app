f = File.open('./test/data/catalogue_message.json', "r")
Catalogue.create_with_products(JSON.parse(f.read, :symbolize_names => true)[:catalogue])