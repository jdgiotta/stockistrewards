class Shop < ActiveRecord::Base
  include ShopifyApp::SessionStorage
  has_many :product_types
  has_many :stockists
  has_many :reward_periods
  has_many :orders
  has_many :imports

  def sync_orders
    order_count = 0
    orders = 0
    puts "INFO: sync_orders SHOP: #{self.inspect}"

    if self.last_reward_period.nil?
      orders = get_orders_since_last_id
    else
      orders = get_reward_period_orders
    end


    while orders.count > 0
      orders.each do |order|
        logger.info order.inspect
        order_record = Order.find_or_initialize_by({shop_id: self.id, shopify_id: order.id})
        next if defined?(order.customer).nil? || defined?(order.shipping_address).nil?
        if order_record.save
          order_record.sync_order(order)
          order_count = order_count + 1
        else
          logger.info "ERROR: ORDER NOT SAVED: "+order.errors.inspect
        end
      end
      orders = get_orders_since_last_id
    end
    self.synced_at = Time.now
    self.save
  end

  def calculate_rewards
    self.stockists.each do |stockist|
      puts "INFO: CALCULATING REWARDS FOR STOCKIST: #{stockist.inspect}"
      stockist.calculate_rewards
    end
    rp = shop.last_reward_period
    rp.calculated_at = Time.now
    rp.save
  end

  def sync_product_types_from_orders
    LineItem.select(:product_type).map{|e| e.product_type}.uniq do |sc|
      unless sc.blank?
        pt = ProductType.find_or_initialize_by({shop_id: self.id, title: sc})
        pt.handle = sc.gsub('-', ' ').downcase
        pt.save
      end
    end
  end

  def sync_product_types_by_smart_collection
    ShopifyAPI::SmartCollection.all.each do |sc|
      pt = ProductType.find_or_initialize_by({shop_id: self.id, title: sc.title})
      pt.handle = sc.handle
      pt.save
    end
  end

  def earliest_start_date
    start_date = Date.today
    self.stockists.each do |s|
      st = s.started_at.blank? ? Date.today : s.started_at
      start_date = [start_date, st].min
    end
    start_date
  end

  def last_reward_period
    reward_periods.last if reward_periods.any?
  end

  def last_calculated_reward_period
    reward_periods.where.not(calculated_at: nil).last if reward_periods.any?
  end

  private

  def earliest_period_date
    last_reward_period.start_date
  end

  def get_orders_since_last_id
    sid = Order.maximum(:shopify_id)
    orders = ShopifyAPI::Order.find(:all, params: {since_id: sid, order: 'created_at ASC', created_at_min: earliest_start_date })
  end

  def get_reward_period_orders
    orders = ShopifyAPI::Order.find(:all, params: {order: 'created_at ASC', created_at_min: self.last_reward_period.start_date })
  end


end
