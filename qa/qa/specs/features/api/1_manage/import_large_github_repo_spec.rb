# frozen_string_literal: true

require 'octokit'
require 'parallel'

# rubocop:disable Rails/Pluck
module QA
  # Only executes in custom job/pipeline
  RSpec.describe 'Manage', :github, :requires_admin, only: { job: 'large-github-import' } do
    describe 'Project import' do
      let(:logger) { Runtime::Logger.logger }
      let(:differ) { RSpec::Support::Differ.new(color: true) }

      let(:api_client) { Runtime::API::Client.as_admin }
      let(:group) do
        Resource::Group.fabricate_via_api! do |resource|
          resource.api_client = api_client
        end
      end

      let(:user) do
        Resource::User.fabricate_via_api! do |resource|
          resource.api_client = api_client
          resource.hard_delete_on_api_removal = true
        end
      end

      let(:github_repo) { 'rspec/rspec-core' }
      let(:github_client) do
        Octokit.middleware = Faraday::RackBuilder.new do |builder|
          builder.response(:logger, logger, headers: false, bodies: false)
        end

        Octokit::Client.new(access_token: Runtime::Env.github_access_token, auto_paginate: true)
      end

      let(:gh_branches) { github_client.branches(github_repo).map(&:name) }
      let(:gh_commits) { github_client.commits(github_repo).map(&:sha) }
      let(:gh_repo) { github_client.repository(github_repo) }

      let(:gh_labels) do
        github_client.labels(github_repo).map { |label| { name: label.name, color: "##{label.color}" } }
      end

      let(:gh_milestones) do
        github_client
          .list_milestones(github_repo, state: 'all')
          .map { |ms| { title: ms.title, description: ms.description } }
      end

      let(:gh_all_issues) do
        github_client.list_issues(github_repo, state: 'all')
      end

      let(:gh_prs) do
        gh_all_issues.select(&:pull_request).each_with_object({}) do |pr, hash|
          hash[pr.title] = {
            body: pr.body || '',
            comments: [*gh_pr_comments[pr.html_url], *gh_issue_comments[pr.html_url]].compact.sort
          }
        end
      end

      let(:gh_issues) do
        gh_all_issues.reject(&:pull_request).each_with_object({}) do |issue, hash|
          hash[issue.title] = {
            body: issue.body || '',
            comments: gh_issue_comments[issue.html_url]
          }
        end
      end

      let(:gh_issue_comments) do
        github_client.issues_comments(github_repo).each_with_object(Hash.new { |h, k| h[k] = [] }) do |c, hash|
          hash[c.html_url.gsub(/\#\S+/, "")] << c.body # use base html url as key
        end
      end

      let(:gh_pr_comments) do
        github_client.pull_requests_comments(github_repo).each_with_object(Hash.new { |h, k| h[k] = [] }) do |c, hash|
          hash[c.html_url.gsub(/\#\S+/, "")] << c.body # use base html url as key
        end
      end

      let(:imported_project) do
        Resource::ProjectImportedFromGithub.fabricate_via_api! do |project|
          project.add_name_uuid = false
          project.name = 'imported-project'
          project.group = group
          project.github_personal_access_token = Runtime::Env.github_access_token
          project.github_repository_path = github_repo
          project.api_client = api_client
        end
      end

      before do
        group.add_member(user, Resource::Members::AccessLevel::MAINTAINER)
      end

      after do |example|
        next if example.pending?

        # save data for comparison after run finished
        save_json(
          "data",
          {
            github: {
              branches: gh_branches,
              commits: gh_commits,
              labels: gh_labels,
              milestones: gh_milestones,
              prs: gh_prs,
              issues: gh_issues
            },
            gitlab: {
              branches: gl_branches,
              commits: gl_commits,
              labels: gl_labels,
              milestones: gl_milestones,
              mrs: mrs,
              issues: gl_issues
            }
          }.to_json
        )
      end

      it 'imports large Github repo via api' do
        imported_project # import the project
        fetch_github_objects # fetch all objects right after import has started

        expect { imported_project.reload!.import_status }.to eventually_eq('finished').within(
          duration: 3600,
          interval: 30
        )

        aggregate_failures do
          verify_repository_import
          verify_labels_import
          verify_milestones_import
          verify_merge_requests_import
          verify_issues_import
        end
      end

      # Persist all objects from repository being imported
      #
      # @return [void]
      def fetch_github_objects
        logger.debug("Fetching objects for github repo: '#{github_repo}'")

        gh_repo
        gh_branches
        gh_commits
        gh_prs
        gh_issues
        gh_labels
        gh_milestones
      end

      # Verify repository imported correctly
      #
      # @return [void]
      def verify_repository_import
        logger.debug("Verifying repository import")
        expect(imported_project.description).to eq(gh_repo.description)
        # check via include, importer creates more branches
        # https://gitlab.com/gitlab-org/gitlab/-/issues/332711
        expect(gl_branches).to include(*gh_branches)
        expect(gl_commits).to match_array(gh_commits)
      end

      # Verify imported merge requests and mr issues
      #
      # @return [void]
      def verify_merge_requests_import
        logger.debug("Verifying merge request import")
        verify_mrs_or_issues('mr')
      end

      # Verify imported issues and issue comments
      #
      # @return [void]
      def verify_issues_import
        logger.debug("Verifying issue import")
        verify_mrs_or_issues('issue')
      end

      # Verify imported labels
      #
      # @return [void]
      def verify_labels_import
        logger.debug("Verifying label import")
        expect(gl_labels).to match_array(gh_labels)
      end

      # Verify milestones import
      #
      # @return [void]
      def verify_milestones_import
        logger.debug("Verifying milestones import")
        expect(gl_milestones).to match_array(gh_milestones)
      end

      private

      # Verify imported mrs or issues
      #
      # @param [String] type verification object, 'mrs' or 'issues'
      # @return [void]
      def verify_mrs_or_issues(type)
        msg = ->(title) { "expected #{type} with title '#{title}' to have" }
        expected = type == 'mr' ? mrs : gl_issues
        actual = type == 'mr' ? gh_prs : gh_issues

        # Compare length to have easy to read overview how many objects are missing
        expect(expected.length).to(
          eq(actual.length),
          "Expected to contain same amount of #{type}s. Expected: #{expected.length}, actual: #{actual.length}"
        )
        actual.each do |title, actual_item|
          logger.debug("Comparing #{type} with title '#{title}'")

          expected_item = expected[title]

          expect(expected_item).to be_truthy, "#{msg.call(title)} been imported"
          next unless expected_item

          expect(expected_item[:body]).to(
            include(actual_item[:body]),
            "#{msg.call(title)} same description. diff:\n#{differ.diff(expected_item[:body], actual_item[:body])}"
          )
          expect(expected_item[:comments].length).to(
            eq(actual_item[:comments].length),
            "#{msg.call(title)} same amount of comments"
          )
          expect(expected_item[:comments]).to match_array(actual_item[:comments])
        end
      end

      # Imported project branches
      #
      # @return [Array]
      def gl_branches
        @gl_branches ||= imported_project.repository_branches(auto_paginate: true).map { |b| b[:name] }
      end

      # Imported project commits
      #
      # @return [Array]
      def gl_commits
        @gl_commits ||= imported_project.commits(auto_paginate: true).map { |c| c[:id] }
      end

      # Imported project labels
      #
      # @return [Array]
      def gl_labels
        @gl_labels ||= imported_project.labels(auto_paginate: true).map { |label| label.slice(:name, :color) }
      end

      # Imported project milestones
      #
      # @return [<Type>] <description>
      def gl_milestones
        @gl_milestones ||= imported_project.milestones(auto_paginate: true).map { |ms| ms.slice(:title, :description) }
      end

      # Imported project merge requests
      #
      # @return [Hash]
      def mrs
        @mrs ||= begin
          logger.debug("Fetching merge requests")
          imported_mrs = imported_project.merge_requests(auto_paginate: true)
          # fetch comments in parallel since we need to do it for each mr separately
          logger.debug("Transforming merge request objects for comparison")
          mrs_hashes = Parallel.map(imported_mrs) do |mr|
            resource = Resource::MergeRequest.init do |resource|
              resource.project = imported_project
              resource.iid = mr[:iid]
              resource.api_client = api_client
            end

            {
              title: mr[:title],
              body: mr[:description],
              comments: resource.comments(auto_paginate: true)
                # remove system notes
                .reject { |c| c[:system] || c[:body].match?(/^(\*\*Review:\*\*)|(\*Merged by:).*/) }
                .map { |c| sanitize(c[:body]) }
            }
          end

          mrs_hashes.each_with_object({}) do |mr, hash|
            hash[mr[:title]] = {
              body: mr[:body],
              comments: mr[:comments]
            }
          end
        end
      end

      # Imported project issues
      #
      # @return [Hash]
      def gl_issues
        @gl_issues ||= begin
          logger.debug("Fetching issues")
          imported_issues = imported_project.issues(auto_paginate: true)
          # fetch comments in parallel since we need to do it for each mr separately
          logger.debug("Transforming issue objects for comparison")
          issue_hashes = Parallel.map(imported_issues) do |issue|
            resource = Resource::Issue.init do |issue_resource|
              issue_resource.project = imported_project
              issue_resource.iid = issue[:iid]
              issue_resource.api_client = api_client
            end

            {
              title: issue[:title],
              body: issue[:description],
              comments: resource.comments(auto_paginate: true).map { |c| sanitize(c[:body]) }
            }
          end

          issue_hashes.each_with_object({}) do |issue, hash|
            hash[issue[:title]] = {
              body: issue[:body],
              comments: issue[:comments]
            }
          end
        end
      end

      # Remove added prefixes by importer
      #
      # @param [String] body
      # @return [String]
      def sanitize(body)
        body.gsub(/\*Created by: \S+\*\n\n/, "")
      end

      # Save json as file
      #
      # @param [String] name
      # @param [String] json
      # @return [void]
      def save_json(name, json)
        File.open("tmp/#{name}.json", "w") { |file| file.write(json) }
      end
    end
  end
end
# rubocop:enable Rails/Pluck
