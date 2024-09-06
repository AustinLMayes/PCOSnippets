require 'common'
require 'pco_api'

@pco_api = PCO::API.new(basic_auth_token: ENV["PCO_API_KEY"], basic_auth_secret: ENV["PCO_API_SECRET"])

def grab_snippet(type_id, plan_id, snippet_id)
  info "Getting items for plan #{plan_id}..."
  items_raw = @pco_api.services.v2.service_types[type_id].plans[plan_id].items.get(per_page: 50)["data"]
  items = []
  items_raw.each do |item|
    desc = item["attributes"]["description"].split("\n") unless item["attributes"]["description"].nil?
    items << {
      type: item["attributes"]["item_type"],
      description: desc,
      title: item["attributes"]["title"],
      service_position: item["attributes"]["service_position"],
      length: item["attributes"]["length"]
    }
  end
  File.open("snippets/#{snippet_id}.json", "w") do |f|
    f.write(JSON.pretty_generate(items))
  end
  info "Saved snippet to snippets/#{snippet_id}.json"
end

def insert_snippet(snippet_id, type_id, plan_id, top: false)
  error "Snippet #{snippet_id} not found" unless File.exists?("snippets/#{snippet_id}.json")
  data = JSON.parse(File.read("snippets/#{snippet_id}.json"))
  raise "Plan #{plan_id} not found" unless @pco_api.services.v2.service_types[type_id].plans[plan_id].exists?
  existing_ids = @pco_api.services.v2.service_types[type_id].plans[plan_id].items.get(per_page: 50)["data"].map { |item| item["id"] }
  inserted = []
  data.each do |item|
    desc = item["description"].join("\n") unless item["description"].nil?
    inserted << @pco_api.services.v2.service_types[type_id].plans[plan_id].items.post(
      {
        data: {
          attributes: {
            item_type: item["type"],
            title: item["title"],
            description: desc,
            service_position: item["service_position"],
            length: item["length"]
          }
        }
      }
    )["data"]["id"]
  end
  if top
    seq = inserted + existing_ids
    @pco_api.services.v2.service_types[type_id].plans[plan_id].item_reorder.post(
      {
        data: {
          "type": "PlanItemReorder",
          "attributes": {
            "sequence": seq
          }
        }
      }
    )
  end
  info "Inserted snippet #{snippet_id} into plan #{plan_id}"
end

AM = 393078

# grab_snippet(AM, 70099338, "pre_show")
insert_snippet("pre_show", AM, 70099363, top: true)
