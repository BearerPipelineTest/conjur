require 'benchmark'
require 'monitoring/pub_sub'

module Monitoring
  module Middleware
    class ConjurCollector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call(env)
        trace(env) { @app.call(env) }
      end

      protected

      def trace(env)
        response = nil
        duration = Benchmark.realtime { response = yield }
        record(env, response.first.to_s, duration)
        return response
      rescue
        nil
      end

      def record(env, code, duration)
        # Publish events based on response code, request path and duration.
        path = [env["SCRIPT_NAME"], env["PATH_INFO"]].join
        PubSub.publish(
          "collector_test_metric",
          code: code,
          path: path
        )
      end

    end
  end
end
