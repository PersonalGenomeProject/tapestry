class PagesController < ApplicationController

  PAGE_KEYWORDS = %w(logged_out introduction home)

  before_filter :ensure_valid
  helper_method :total_user_count, :recent_students, :recent_sponsors, :recent_causes
  skip_before_filter :login_required, :only => [:show]
  skip_before_filter :ensure_enrolled, :only => [:show]

  def show

    # Allow easy creation of initial admin user when the db is empty
    if !current_user and User.all.count == 0 then
      redirect_to initial_user_url
      return
    end

    if current_user and current_user.enrolled and not current_user.enrollment_accepted
      redirect_to enrollment_application_results_url
      return
    end

    # For users who are researchers but *not* enrolled
    if logged_in? and params[:id] != 'researcher_tools' and current_user and current_user.enrolled.nil? and current_user.researcher then
      redirect_to "/pages/researcher_tools"
      return
    end

    if logged_in? and params[:id] == 'researcher_tools' then
      @google_surveys = GoogleSurvey.find_all_by_user_id(current_user.id)
      @studies = Study.where('researcher_id = ?',current_user.id)
      @kit_design_samples = KitDesignSample.find_all_by_kit_design_id(current_user.kit_designs).sort { |a,b| a.name <=> b.name }

      @requested_studies = Study.requested.where('researcher_id = ?',current_user.id)
      @approved_studies = Study.approved.where('researcher_id = ?',current_user.id)
      @draft_studies = Study.draft.where('researcher_id = ?',current_user.id)
    end

    # Only enrolled users can go to the studies page
    if params[:id] == 'studies'
      authorized? or return access_denied
      current_user.enrolled? or return redirect_to root_url
    end

    if params[:id] == 'studies'
      @kits = Kit.participant(current_user.id).sort{ |a,b| b.updated_at <=> a.updated_at }
    end

    # This page has now been replaced by the studies page
    # This redirect can probably go in a few months. I removed the specimen_collection page on 2011-07-26
    if params[:id] == 'specimen_collection' then
      redirect_to "/pages/studies"
      return
    end

    params[:page] = params[:page].to_i
    params[:page] = 1 if params[:page] == 0

    @enrolled = User.enrolled.find(:all).sort{ |a,b| a.enrolled <=> b.enrolled }.paginate(:page => params[:page] || 1, :per_page => 100)

    fetch_ivars
    render :template => current_page
  end

  protected

  def ensure_valid
    unless template_exists?(current_page)
      raise ActionController::RoutingError,
            "No such static page: #{current_page.inspect}"
    end
  end

  def current_page
    "pages/#{params[:id].to_s.downcase}"
  end

  # TODO: Refactor
  def fetch_ivars
    if current_user
      @steps            = EnrollmentStep.ordered
      @step_completions = current_user.enrollment_step_completions
      @next_step        = current_user.next_enrollment_step
    else
      @steps            = []
      @step_completions = []
      @next_step        = nil
    end
  end

end
