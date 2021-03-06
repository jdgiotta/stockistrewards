class OrderSyncJob < ApplicationJob
  queue_as :default

  def perform(shop)
    if Sidekiq::Queue.all.select {|q| q.name == 'default' }.first.size == 0
      session = ShopifyAPI::Session.new(shop.shopify_domain, shop.shopify_token)
      ShopifyAPI::Base.activate_session(session)

      logger.info "ORDER SYNC JOB - sync_orders"
      shop.sync_orders
      logger.info "ORDER SYNC JOB - product_types"
      shop.sync_product_types_from_orders
      logger.info "ORDER SYNC JOB - calculate_rewards"
      shop.calculate_rewards
    end
  end
end
