require 'csv'
require 'time'
require 'pry'

require_relative 'user'
require_relative 'trip'

module RideShare
  class TripDispatcher
    attr_reader :drivers, :passengers, :trips

    def initialize(user_file = 'support/users.csv',
      trip_file = 'support/trips.csv', drivers_file = 'support/drivers.csv')
      @passengers = load_users(user_file)
      @drivers = load_drivers(drivers_file)
      replace_passenger(@passengers, @drivers)
      @trips = load_trips(trip_file)

    end


    def load_users(filename)
      users = []

      CSV.read(filename, headers: true).each do |line|
        input_data = {}
        input_data[:id] = line[0].to_i
        input_data[:name] = line[1]
        input_data[:phone] = line[2]

        users << User.new(input_data)

      end

      return users
    end

    def load_drivers(filename)
      drivers = []

      CSV.read(filename, headers: true, header_converters: :symbol).each do |line|

        user = find_passenger(line[:id].to_i)

        driver_data = {}
        driver_data[:id] = user.id.to_i
        driver_data[:name] = user.name
        driver_data[:phone] = user.phone_number
        driver_data[:vin] = line[:vin]
        driver_data[:status] = line[:status].to_sym

        drivers << Driver.new(driver_data)

      end

      return drivers
    end

    def replace_passenger(passenger_array, driver_array)
      driver_n_passengers = passenger_array.map do |passenger|
        driver_array.each do |driver|
          if passenger.id == driver.id
            passenger = driver
          end
        end
        passenger
      end
      passenger_array.replace(driver_n_passengers)

      return passenger_array
    end

    def load_trips(filename)
      trips = []
      trip_data = CSV.open(filename, 'r', headers: true, header_converters: :symbol)

      trip_data.each do |raw_trip|
        passenger = find_passenger(raw_trip[:passenger_id].to_i)

        driver = find_driver(raw_trip[:driver_id].to_i)

        parsed_trip = {
          id: raw_trip[:id].to_i,
          passenger: passenger,
          driver: driver,
          start_time: Time.parse(raw_trip[:start_time]),
          end_time: Time.parse(raw_trip[:end_time]),
          cost: raw_trip[:cost].to_f,
          rating: raw_trip[:rating].to_i
        }

        trip = Trip.new(parsed_trip)
        passenger.add_trip(trip)
        driver.add_driven_trip(trip)

        trips << trip

      end

      return trips
    end

    def find_passenger(id)
      check_id(id)
      return @passengers.find { |passenger| passenger.id == id }
    end

    def find_driver(id)
      check_id(id)
      return @drivers.find { |driver| driver.id == id }
    end

    def inspect
      return "#<#{self.class.name}:0x#{self.object_id.to_s(16)} \
      #{trips.count} trips, \
      #{drivers.count} drivers, \
      #{passengers.count} passengers>"
    end

    def request_trip(user_id)
      new_trip = {

        id: trips.last.id + 1,
        passenger: find_passenger(user_id),
        driver: find_available_driver(user_id),
        start_time: Time.now,
        end_time: nil,
        cost: nil,
        rating: nil
      }
      requested_trip = Trip.new(new_trip)

      requested_trip.driver.add_driven_trip(requested_trip)

      requested_trip.passenger.add_trip(requested_trip)
      @trips << requested_trip

      return requested_trip

    end

    def find_available_driver(user_id)

      available_drivers = @drivers.select{|driver| driver.status == :AVAILABLE}

      available_drivers = available_drivers.reject{|driver| driver.id == user_id}

      if available_drivers.length == 0
        raise ArgumentError, "There are no available drivers"
      else
        available_drivers.each do |driver|
          if driver.driven_trips.length == 0
            driver.status = :UNAVAILABLE
            return driver
          end
        end

        available_drivers.sort_by {|driver| driver.driven_trips.last.end_time }
        available_drivers[0].status = :UNAVAILABLE
        return available_drivers[0]

      end

    end

    private

    def check_id(id)
      raise ArgumentError, "ID cannot be blank or less than zero. (got #{id})" if id.nil? || id <= 0
    end
  end
end
