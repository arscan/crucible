module Api
  class ServersController < ApplicationController
    respond_to :json

    def update
      # Unauthenticated users can't update.
      # unless current_user
      #   head :forbidden
      #   return
      # end
      server = Server.find(params[:id])
      server.update(server_params)
      if server.save
        respond_with server
      else
        respond_with server, status: 422
      end
    end

    def destroy
      # Unauthenticated users can't delete.
      unless current_user
        head :forbidden
        return
      end
      server = Server.find(params[:id])
      server.destroy

      respond_with server, location: api_servers_path
    end

    def conformance
      server = Server.find(params[:id])
      render json: {conformance: server.load_conformance(params[:refresh])}
    end

    def summary
      summary = Server.find(params[:id]).summary
      render json: {summary: summary}
    end

    def aggregate_run
      server = Server.find(params[:id])
      aggregate_run = server.aggregate_run
      return unless aggregate_run
      if (params[:only_failures])
        aggregate_run.results.select! {|r| r if r['status'] != 'pass'}
      end
      render json: server.aggregate_run
    end

    def generate_summary
      test_run = TestRun.find(params[:test_run_id])
      server = Server.find(params[:id])
      Aggregate.update(server, test_run)
      compliance = Aggregate.get_compliance(server)

      summary = Summary.new({server_id: server.id, test_run: test_run, compliance: compliance, generated_at: Time.now})
      server.summary = summary
      server.percent_passing = (compliance['passed'].to_f / ([compliance['total'].to_f || 0, 1].max)) * 100.0
      summary.save!
      server.save!

      render json: {summary: summary}
    end

    def oauth_params
      server = Server.find(params[:id])
      if server
        server.client_id = params[:client_id]
        server.client_secret = params[:client_secret]
        server.state = params[:state]
        server.authorize_url = params[:authorize_url]
        server.token_url = params[:token_url]
        server.save
        render json: { success: true }
        # render status: 500, text: 'Error'
      end
    end

    private

    def server_params
      params.require(:server).permit(:url, :name)
    end
  end
end
