require 'command_class'

module Authentication
  module AuthnJwt
    # Generic JWT authenticator that receive JWT vendor configuration and uses to validate that the authentication
    # request is valid, and return conjur authn token accordingly
    Authenticate = CommandClass.new(
      dependencies: {
        token_factory: TokenFactory.new,
        logger: Rails.logger
      },
      inputs: %i[jwt_configuration authenticator_input]
    ) do

      def call
        create_authentication_parameters
        validate_and_decode_token
        get_jwt_identity
        validate_restrictions
        new_token
      end

      private

      def create_authentication_parameters
        @logger.debug(LogMessages::Authentication::AuthnJwt::CREATING_AUTHENTICATION_PARAMETERS_OBJECT.new)
        @authentication_parameters = Authentication::AuthnJwt::AuthenticationParameters.new(@authenticator_input)
      end

      def validate_and_decode_token
        @logger.debug(LogMessages::Authentication::AuthnJwt::VALIDATE_AND_DECODE_TOKEN.new)
        @authentication_parameters.decoded_token = @jwt_configuration.validate_and_decode_token(@authentication_parameters)
      end

      def get_jwt_identity
        # Will be changed when real get identity implemented
        @logger.debug(LogMessages::Authentication::AuthnJwt::GET_JWT_IDENTITY.new)
        @authentication_parameters.jwt_identity =  @jwt_configuration.jwt_identity(@authentication_parameters)
      end

      def validate_restrictions
        @logger.debug(LogMessages::Authentication::AuthnJwt::CHECKING_IDENTITY_FIELD_EXISTS.new)
        unless @jwt_configuration.validate_restrictions(@authentication_parameters)
          raise "not matching policy annotations"
        end
      end

      def new_token
        @logger.debug(LogMessages::Authentication::AuthnJwt::JWT_AUTHENTICATION_PASSED.new)
        @token_factory.signed_token(
          account: @authenticator_input.account,
          username: @authenticator_input.username
        )
      end
    end
  end
end