class PagesController < ApplicationController

  include RdfModule

  # for calling from view
  helper_method :get_rdf_json

  respond_to :json, :html

  # order of next two lines is very important!
  # before_filter need to be before load_and_authorize_resource
  before_filter :get_the_page
  # methods, that need to check permissions
  load_and_authorize_resource :only => [:delete, :rename, :update, :apply_findings, :update_repo]

  def get_the_page
    # if no title -> set default wiki startpage '@project'
    full_title = params[:id].nil? ? '@project' : params[:id]
    @page = PageModule.find_by_full_title full_title
    # page not found and user can create page -> create new page by full_title
    @page = PageModule.create_page_by_full_title full_title if @page.nil? && (can? :create, Page.new)
    # if no page created/found
    if !@page
      respond_to do |format|
        format.html do
          flash[:error] = "Page wasn't not found. Redirected to main wiki page"
          go_to_homepage
        end
        format.json { render :json => {success: false}, :status => 404 }
      end
    end
  end

  def update_repo
    repo_link = params[:repo_link]
    # if no link to repo -> create it
    @page.repo_link = RepoLink.new if @page.repo_link.nil?
    # fill props
    @page.repo_link.folder = repo_link[:folder]
    @page.repo_link.user = repo_link[:user_repo].split('/').first
    @page.repo_link.repo = repo_link[:user_repo].split('/').last
    # assign page
    @page.repo_link.page = @page
    # save page and link
    (@page.save and @page.repo_link.save) ?
      flash[:success]="Updated linked repo" : flash[:error] = "Failed to update linked repo"
    # TODO: restore request on matching server
    redirect_to  "/wiki/#{@page.url}"
  end

  def apply_findings
    JSON.parse(@page.worker_findings).each do |finding|
      finding.keys.each do |finding_key|
        if finding[finding_key]
          finding[finding_key].each do |one_prop|
            predicate_part = finding_key == "features" ? 'implements' : 'uses'
            @page.inject_triple "#{predicate_part}::#{finding_key.singularize.capitalize}:#{one_prop}"
          end
        end
      end
      result = @page.save
      message_type= result ? :success : :error
      message = result ? "You have successfully added to metadata worker findings" :
          "Something was wrong. Please try again later"
      flash[message_type] = message
    end
    redirect_to  "/wiki/#{@page.url}"
  end

  def get_rdf
    title = params[:id]
    graph_to_return = RDF::Graph.new
    get_rdf_graph(title).each do |st|
      graph_to_return << (st.subject.to_s === "IN" ? (reverse_statement st, title) : st)
    end
    respond_with graph_to_return.dump(:ntriples)
  end

  def get_json
    respond_with get_rdf_json(params[:id], params[:directions])
  end

  def delete
    result = @page.delete
    # generate flash_message if deleting was successful
    flash[:notice] = 'Page ' + @page.full_title + ' was deleted' if result
    render :json => {:success => result}
  end

  def snapshot
    @doc = SnapshotModule.get_snapshot(@page)
    @page.snapshot = @doc
    @page.save
    @doc = @page.snapshot
    logger.info("snapshot: #{@s}")
    respond_to do |format|
      format.html {
        render :html => @doc, :layout => "snapshot"
      }
    end
  end

  def show

    if params.has_key?(:_escaped_fragment_)
       begin
        if @page.snapshot == nil
          logger.debug("Page doesn't have a snapshot")
          @doc = SnapshotModule.get_snapshot(@page)
        else
          logger.debug("Page already has a snapshot")
          @doc = @page.snapshot
        end
        respond_to do |format|
          format.html {
            render :html => @doc, :layout => "snapshot"
          }
        end
      rescue
        @error_message="#{$!}"
        logger.error(@error_message)
        redirect_to :status => 404
      end

    else

      respond_to do |format|
        format.html {
          # if need redirect? -> wiki url conventions -> do a redirect
          good_link = @page.url
          if good_link != params[:id]
            redirect_to '/wiki/'+ good_link and return
          end
          # no redirect? -> render the page
          render :html => @page
        }

        format.json { render :json => {
          'id'        => @page.full_title,
          'content'   => @page.raw_content,
          'sections'  => @page.sections,
          'history'   => @page.get_last_change,
          'backlinks' => @page.backlinks
        }}

      end
    end
  end

  def parse
    html = @page.parse params[:content]
    render :json => {:success => true, :html => html}
  end

  def search
    @query_string = params[:q]
    if @query_string == ''
      flash[:notice] = 'Please write something, if you want to search something'
      go_to_homepage
    else
      @search_results = PageModule.search @query_string
      respond_with @search_results
    end
  end

  def summary
    render :json => {:sections => @page.sections, :internal_links => @page.internal_links}
  end

  # get all sections for a page
  def sections
    respond_with @page.sections
  end

  # get all internal links for the page
  def internal_links
    respond_with @page.internal_links
  end

  def update
    sections = params[:sections]
    content = params[:content]
    new_full_title = PageModule.unescape_wiki_url params[:newTitle]

    history_track = @page.create_track current_user
    result = @page.update_or_rename_page(new_full_title, content, sections)
    history_track.save if result
    render :json => {
      :success => result,
      :newTitle => @page.url
    }
  end

  def section
    respond_with ({:content => @page.section(params[:full_title])}).to_json
  end

end
