class ReportsController < ApplicationController
  before_filter :authenticate_user!, only: [:index]
  before_filter :ensure_dispatcher, only: %w(index active history)

  def ensure_dispatcher
    redirect_to edit_user_registration_path unless current_user.role == 'dispatcher'
  end

  def new
    @blank_report = Report.new
  end

  def index
    @unassigned_reports = current_user.reports.unassigned
    @pending_reports = current_user.reports.pending
  end

  def active
    @reports = Report.accepted
  end

  def history
    @reports = Report.completed
  end

  def deleted
    @reports = Report.deleted
  end

  def create
    begin
      @report = Report.create(report_params)
      if @report.save
        Pusher.trigger("reports" , "refresh", {})
        render json: @report
      else
        render json: @report
      end
    rescue Exception => e
      Rails.logger.error e.message
      e.backtrace.each do |b|
        Rails.logger.error b
      end
    end
  end

  def destroy
    @report = Report.find(params[:id])
    @report.status = "deleted"
    @report.save
    redirect_to action: 'history'
  end

  def upload
    @report = Report.find(params[:id])
    update_params = report_params
    @report.update_attributes(update_params)
    p "Report#upload", @report.image_file_name
    @report.save

    Pusher.trigger("reports" , "refresh", {})
    render json: {success: true}
  end

  def update
    begin
    @report = Report.find(params[:id])
    update_params = report_params
    if update_params[:image]
      bytes = Base64.decode64(update_params.delete(:image))
      update_params[:image] = StringIO.new(bytes)
    end
    @report.update_attributes!(update_params)

    Pusher.trigger("reports" , "refresh", {})
    render json: {success: true}
    rescue
      binding.pry
    end
  end

  def historify
    Report.find(params[:id]).update_attributes(status: "completed")
    Pusher.trigger("reports" , "refresh", {})
  end


  def show
    @report = Report.find(params[:id])
    @metaphone = Log.new
  end

  def report_params
    report_attributes = [:name, :phone, :lat, :long, :status, :nature,
      :setting, :observations, :age, :gender, :race, :address, :neighborhood, :image]

    params.require(:report).permit report_attributes
  end
end
