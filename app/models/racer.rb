class Racer
  include ActiveModel::Model
  attr_accessor :id, :number, :first_name, :last_name, :gender, :group, :secs

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    self.mongo_client['racers']
  end

  def initialize(params={})
    @id=params[:_id].nil? ? params[:id] : params[:_id].to_s
    @number=params[:number].to_i
    @first_name=params[:first_name]
    @last_name=params[:last_name]
    @gender=params[:gender]
    @group=params[:group]
    @secs=params[:secs].to_i
  end

  # @id is assigned after successful save
  def persisted?
    !@id.nil?
  end

  def created_at
    nil
  end
  def updated_at
    nil
  end

  def self.all(prototype={},sort={:number=>1},skip=0,limit=nil)
    data_fields = [:_id, :number, :first_name, :last_name, :gender, :group, :secs]

    tmp = {}
    sort.each do |k,v|
      k = k.to_sym == :number ? :number : k.to_sym
      tmp[k] = v if data_fields.include?(k)
    end
    sort = tmp

    prototype = prototype.symbolize_keys.slice(:_id, :number, :first_name, :last_name, :gender, :group, :secs) if !prototype.nil?

    Rails.logger.debug {"getting all racers, prototype=#{prototype}, sort=#{sort}, skip=#{skip}, limit=#{limit}"}

    result = collection.find(prototype)
                       .projection({number: true, first_name: true, last_name: true, gender: true, group: true, secs: true})
                       .sort(sort)
                       .skip(skip)
    result = result.limit(limit) if !limit.nil?

    return result
  end

  def self.find(id)
    Rails.logger.debug {"getting racer with id: #{id}"}

    id = BSON::ObjectId.from_string(id) unless id === BSON::ObjectId

    result = collection.find(:_id => id)
                       .projection({_id: true, number: true, first_name: true, last_name: true, gender: true, group: true, secs: true})
                       .first
    return result.nil? ? nil : Racer.new(result)
  end

  def save
    Rails.logger.debug {"saving current state #{self}"}

    result = self.class.collection
                 .insert_one(_id: @id, number: @number, first_name: @first_name, last_name: @last_name, gender: @gender, group: @group, secs: @secs)
    @id = result.inserted_id
  end

  def update(params)
    Rails.logger.debug { "updating #{self} with #{params}" }

    @number=params[:number].to_i
    @first_name=params[:first_name]
    @last_name=params[:last_name]
    @gender=params[:gender]
    @group=params[:group]
    @secs=params[:secs].to_i

    params.slice!(:number, :first_name, :last_name, :gender, :group, :secs) if !params.nil?
    self.class.collection
              .find(:_id => BSON::ObjectId.from_string(@id))
              .update_one(params)
  end

  def destroy
    self.class.collection
              .find(:_id => BSON::ObjectId.from_string(@id))
              .delete_one
  end

  def self.paginate(params)
    page = (params[:page] || 1).to_i
    limit = (params[:per_page] || 30).to_i
    skip = (page-1)*limit
    sort = { :number => 1 }

    racers = []
    all({}, sort, skip, limit).each do |doc|
      racers << Racer.new(doc)
    end

    total = all({}, sort, 0, 1).count

    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(racers)
    end
  end
end
