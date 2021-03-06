module Api
  class TestRunsController < ApplicationController
    respond_to :json

    def show
      test_run = TestRun.includes(:test_results).find(params[:id])
      test_run['test_results'] = test_run.test_results
      render json: {test_run: test_run}
    end


    def create
      run = TestRun.new(run_params)
      run.date = Time.now

      if run.save()
        run = {:test_run => run}
        respond_with run, location: api_test_runs_path
      end
    end

    def index
      @runs = []

      if not current_user.nil?
        @runs = current_user.test_runs
      end
      render json:{test_runs: @runs}
    end

    private
    def run_params
      params.require(:test_run).permit(:server_id)
    end
  end
end
