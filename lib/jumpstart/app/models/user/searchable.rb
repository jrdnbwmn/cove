module User::Searchable
  # Replace with a search engine like Meilisearch, ElasticSearch, or pg_search to provide better results
  # Using arel matches allows for database agnostic like queries

  extend ActiveSupport::Concern

  class_methods do
    def search(query)
      where(arel_table[:name].matches("%#{sanitize_sql_like(query.to_s)}%"))
    end
  end
end
