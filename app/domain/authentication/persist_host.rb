# frozen_string_literal: true

require 'command_class'

module Authentication

  # Policy details about a host user
  class AuthHostDetails
    include ActiveModel::Validations
    attr_reader :id, :annotations

    def initialize(json_data, constraints: nil)
      @json_data = json_data
      @constraints = constraints

      @id = @json_data['id'] if @json_data.include?('id')
      @annotations = @json_data.include?('annotations') ? @json_data['annotations'] : {}
    end

    private

    def annotation_pattern
      %r{authn-[a-z8]+/}
    end

    # Get annotations defining authenticator variables (formatted as authn-<authenticator>/<annotation name>)
    # We have to do this in order to allow users to define custom annotations
    def auth_annotations
      @annotations.keys.keep_if { |annotation| annotation.start_with?(annotation_pattern) }
    end

    def validate_annotations
      # remove the authn-<authenticator>/ prefix from each authenticator
      pruned_annotations = auth_annotations.map {|annot| annot.sub(annotation_pattern, '')}
      begin
        @constraints&.validate(resource_restrictions: pruned_annotations)
      rescue => e
        errors.add(:annotations, e.message)
      end
    end

    validates(
      :id,
      presence: true
    )

    validate :validate_annotations
  end

  # Creates a new host user which uses the given authenticator
  class PersistAuthHost
    extend CommandClass::Include

    command_class(
      dependencies: {
        logger: Rails.logger,
        policy_loader: Policy::LoadPolicy.new
      },
      inputs: %i[conjur_account authenticator service_id resource current_user client_ip host_data]
    ) do
      def call
        raise ArgumentError, @host_data.errors.full_messages unless @host_data.valid?

        host_policy = initialize_host_policy(
          policy_loader: @policy_loader,
          resource: @resource,
          current_user: @current_user,
          client_ip: @client_ip,
          service_id: @service_id,
          authenticator: @authenticator,
          host_data: @host_data
        )

        host_policy[:policy].values[:policy_text]
      end

      private

      def host_policy(service_id:, authenticator:, host_data:)
        @host_policy ||= ApplicationController.renderer.render(
          template: "policies/authn-k8s-host",
          locals: {
            service_id: service_id,
            authenticator: authenticator,
            hosts: [ host_data ]
          }
        )
      end

      def initialize_host_policy(policy_loader:, resource:, service_id:, authenticator:, host_data:, current_user:, client_ip:)
        policy_loader.(
          delete_permitted: false,
          action: :update,
          resource: resource,
          policy_text: host_policy(service_id: service_id, authenticator: authenticator, host_data: host_data),
          current_user: current_user,
          client_ip: client_ip
        )
      end
    end
  end

end