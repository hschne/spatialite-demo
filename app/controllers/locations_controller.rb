class LocationsController < ApplicationController
  def index
    @location = Location.new
    @locations_geojson = Location.all.map(&:to_geojson).to_json
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      redirect_to root_path, notice: "Location added!"
    else
      redirect_to root_path, alert: @location.errors.full_messages.to_sentence
    end
  end

  private

  def location_params
    params.expect(location: [:name, :latitude, :longitude])
  end
end
