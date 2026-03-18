class LocationsController < ApplicationController
  def index
    @locations_geojson = Location.to_feature_collection.to_json
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      redirect_to root_path, notice: "Location added!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def location_params
    params.expect(location: [:name, :latitude, :longitude])
  end
end
