# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'File blob', :js do
  include MobileHelpers

  let(:project) { create(:project, :public, :repository) }

  def visit_blob(path, anchor: nil, ref: 'master')
    visit project_blob_path(project, File.join(ref, path), anchor: anchor)

    wait_for_requests
  end

  def create_file(file_name, content)
    project.add_maintainer(project.creator)

    Files::CreateService.new(
      project,
      project.creator,
      start_branch: 'master',
      branch_name: 'master',
      commit_message: "Add #{file_name}",
      file_path: file_name,
      file_content: <<-SPEC.strip_heredoc
        #{content}
      SPEC
    ).execute
  end

  context 'Ruby file' do
    before do
      visit_blob('files/ruby/popen.rb')

      wait_for_requests
    end

    it 'displays the blob' do
      aggregate_failures do
        # shows highlighted Ruby code
        expect(page).to have_css(".js-syntax-highlight")
        expect(page).to have_content("require 'fileutils'")

        # does not show a viewer switcher
        expect(page).not_to have_selector('.js-blob-viewer-switcher')

        # shows an enabled copy button
        expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')

        # shows a raw button
        expect(page).to have_link('Open raw')
      end
    end

    it 'displays file actions on all screen sizes' do
      file_actions_selector = '.file-actions'

      resize_screen_sm
      expect(page).to have_selector(file_actions_selector, visible: true)

      resize_screen_xs
      expect(page).to have_selector(file_actions_selector, visible: true)
    end
  end

  context 'Markdown file' do
    context 'visiting directly' do
      before do
        visit_blob('files/markdown/ruby-style-guide.md')

        wait_for_requests
      end

      it 'displays the blob using the rich viewer' do
        aggregate_failures do
          # hides the simple viewer
          expect(page).to have_selector('.blob-viewer[data-type="simple"]', visible: false)
          expect(page).to have_selector('.blob-viewer[data-type="rich"]')

          # shows rendered Markdown
          expect(page).to have_link("PEP-8")

          # shows a viewer switcher
          expect(page).to have_selector('.js-blob-viewer-switcher')

          # shows a disabled copy button
          expect(page).to have_selector('.js-copy-blob-source-btn.disabled')

          # shows a raw button
          expect(page).to have_link('Open raw')
        end
      end

      context 'switching to the simple viewer' do
        before do
          find('.js-blob-viewer-switch-btn[data-viewer=simple]').click

          wait_for_requests
        end

        it 'displays the blob using the simple viewer' do
          aggregate_failures do
            # hides the rich viewer
            expect(page).to have_selector('.blob-viewer[data-type="simple"]')
            expect(page).to have_selector('.blob-viewer[data-type="rich"]', visible: false)

            # shows highlighted Markdown code
            expect(page).to have_css(".js-syntax-highlight")
            expect(page).to have_content("[PEP-8](http://www.python.org/dev/peps/pep-0008/)")

            # shows an enabled copy button
            expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')
          end
        end

        context 'switching to the rich viewer again' do
          before do
            find('.js-blob-viewer-switch-btn[data-viewer=rich]').click

            wait_for_requests
          end

          it 'displays the blob using the rich viewer' do
            aggregate_failures do
              # hides the simple viewer
              expect(page).to have_selector('.blob-viewer[data-type="simple"]', visible: false)
              expect(page).to have_selector('.blob-viewer[data-type="rich"]')

              # shows an enabled copy button
              expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')
            end
          end
        end
      end
    end

    context 'when ref switch' do
      def switch_ref_to(ref_name)
        first('.qa-branches-select').click

        page.within '.project-refs-form' do
          click_link ref_name
          wait_for_requests
        end
      end

      it 'displays single highlighted line number of different ref' do
        visit_blob('files/js/application.js', anchor: 'L1')

        switch_ref_to('feature')

        page.within '.blob-content' do
          expect(find_by_id('LC1')[:class]).to include("hll")
        end
      end

      it 'displays multiple highlighted line numbers of different ref' do
        visit_blob('files/js/application.js', anchor: 'L1-3')

        switch_ref_to('feature')

        page.within '.blob-content' do
          expect(find_by_id('LC1')[:class]).to include("hll")
          expect(find_by_id('LC2')[:class]).to include("hll")
          expect(find_by_id('LC3')[:class]).to include("hll")
        end
      end

      it 'displays no highlighted number of different ref' do
        Files::UpdateService.new(
          project,
          project.owner,
          commit_message: 'Update',
          start_branch: 'feature',
          branch_name: 'feature',
          file_path: 'files/js/application.js',
          file_content: 'new content'
        ).execute

        project.commit('feature').diffs.diff_files.first

        visit_blob('files/js/application.js', anchor: 'L3')
        switch_ref_to('feature')

        page.within '.blob-content' do
          expect(page).not_to have_css('.hll')
        end
      end

      context 'successfully change ref of similar name' do
        before do
          project.repository.create_branch('dev')
          project.repository.create_branch('development')
        end

        it 'switch ref from longer to shorter ref name' do
          visit_blob('files/js/application.js', ref: 'development')
          switch_ref_to('dev')

          aggregate_failures do
            expect(page.find('.file-title-name').text).to eq('application.js')
            expect(page).not_to have_css('flash-container')
          end
        end

        it 'switch ref from shorter to longer ref name' do
          visit_blob('files/js/application.js', ref: 'dev')
          switch_ref_to('development')

          aggregate_failures do
            expect(page.find('.file-title-name').text).to eq('application.js')
            expect(page).not_to have_css('flash-container')
          end
        end
      end

      it 'successfully changes ref when the ref name matches the project name' do
        project.repository.create_branch(project.name)

        visit_blob('files/js/application.js', ref: project.name)
        switch_ref_to('master')

        aggregate_failures do
          expect(page.find('.file-title-name').text).to eq('application.js')
          expect(page).not_to have_css('flash-container')
        end
      end
    end

    context 'visiting with a line number anchor' do
      before do
        visit_blob('files/markdown/ruby-style-guide.md', anchor: 'L1')
      end

      it 'displays the blob using the simple viewer' do
        aggregate_failures do
          # hides the rich viewer
          expect(page).to have_selector('.blob-viewer[data-type="simple"]')
          expect(page).to have_selector('.blob-viewer[data-type="rich"]', visible: false)

          # highlights the line in question
          expect(page).to have_selector('#LC1.hll')

          # shows highlighted Markdown code
          expect(page).to have_css(".js-syntax-highlight")
          expect(page).to have_content("[PEP-8](http://www.python.org/dev/peps/pep-0008/)")

          # shows an enabled copy button
          expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')
        end
      end
    end
  end

  context 'Markdown rendering' do
    before do
      project.add_maintainer(project.creator)

      Files::CreateService.new(
        project,
        project.creator,
        start_branch: 'master',
        branch_name: 'master',
        commit_message: "Add RedCarpet and CommonMark Markdown ",
        file_path: 'files/commonmark/file.md',
        file_content: "1. one\n  - sublist\n"
      ).execute
    end

    context 'when rendering default markdown' do
      before do
        visit_blob('files/commonmark/file.md')

        wait_for_requests
      end

      it 'renders using CommonMark' do
        aggregate_failures do
          expect(page).to have_content("sublist")
          expect(page).not_to have_xpath("//ol//li//ul")
        end
      end
    end
  end

  context 'Markdown file (stored in LFS)' do
    before do
      project.add_maintainer(project.creator)

      Files::CreateService.new(
        project,
        project.creator,
        start_branch: 'master',
        branch_name: 'master',
        commit_message: "Add Markdown in LFS",
        file_path: 'files/lfs/file.md',
        file_content: project.repository.blob_at('master', 'files/lfs/lfs_object.iso').data
      ).execute
    end

    context 'when LFS is enabled on the project' do
      before do
        allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)
        project.update_attribute(:lfs_enabled, true)

        visit_blob('files/lfs/file.md')

        wait_for_requests
      end

      it 'displays an error' do
        aggregate_failures do
          # hides the simple viewer
          expect(page).to have_selector('.blob-viewer[data-type="simple"]', visible: false)
          expect(page).to have_selector('.blob-viewer[data-type="rich"]')

          # shows an error message
          expect(page).to have_content('The rendered file could not be displayed because it is stored in LFS. You can download it instead.')

          # shows a viewer switcher
          expect(page).to have_selector('.js-blob-viewer-switcher')

          # does not show a copy button
          expect(page).not_to have_selector('.js-copy-blob-source-btn')

          # shows a download button
          expect(page).to have_link('Download')
        end
      end

      context 'switching to the simple viewer' do
        before do
          find('.js-blob-viewer-switcher .js-blob-viewer-switch-btn[data-viewer=simple]').click

          wait_for_requests
        end

        it 'displays an error' do
          aggregate_failures do
            # hides the rich viewer
            expect(page).to have_selector('.blob-viewer[data-type="simple"]')
            expect(page).to have_selector('.blob-viewer[data-type="rich"]', visible: false)

            # shows an error message
            expect(page).to have_content('The source could not be displayed because it is stored in LFS. You can download it instead.')

            # does not show a copy button
            expect(page).not_to have_selector('.js-copy-blob-source-btn')
          end
        end
      end
    end

    context 'when LFS is disabled on the project' do
      before do
        visit_blob('files/lfs/file.md')

        wait_for_requests
      end

      it 'displays the blob' do
        aggregate_failures do
          # shows text
          expect(page).to have_content('size 1575078')

          # does not show a viewer switcher
          expect(page).not_to have_selector('.js-blob-viewer-switcher')

          # shows an enabled copy button
          expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')

          # shows a raw button
          expect(page).to have_link('Open raw')
        end
      end
    end
  end

  context 'PDF file' do
    before do
      project.add_maintainer(project.creator)

      Files::CreateService.new(
        project,
        project.creator,
        start_branch: 'master',
        branch_name: 'master',
        commit_message: "Add PDF",
        file_path: 'files/test.pdf',
        file_content: project.repository.blob_at('add-pdf-file', 'files/pdf/test.pdf').data
      ).execute

      visit_blob('files/test.pdf')

      wait_for_requests
    end

    it 'displays the blob' do
      aggregate_failures do
        # shows rendered PDF
        expect(page).to have_selector('.js-pdf-viewer')

        # does not show a viewer switcher
        expect(page).not_to have_selector('.js-blob-viewer-switcher')

        # does not show a copy button
        expect(page).not_to have_selector('.js-copy-blob-source-btn')

        # shows a download button
        expect(page).to have_link('Download')
      end
    end
  end

  context 'Jupiter Notebook file' do
    before do
      project.add_maintainer(project.creator)

      Files::CreateService.new(
        project,
        project.creator,
        start_branch: 'master',
        branch_name: 'master',
        commit_message: "Add Jupiter Notebook",
        file_path: 'files/basic.ipynb',
        file_content: project.repository.blob_at('add-ipython-files', 'files/ipython/basic.ipynb').data
      ).execute

      visit_blob('files/basic.ipynb')

      wait_for_requests
    end

    it 'displays the blob' do
      aggregate_failures do
        # shows rendered notebook
        expect(page).to have_selector('.js-notebook-viewer-mounted')

        # does show a viewer switcher
        expect(page).to have_selector('.js-blob-viewer-switcher')

        # show a disabled copy button
        expect(page).to have_selector('.js-copy-blob-source-btn.disabled')

        # shows a raw button
        expect(page).to have_link('Open raw')

        # shows a download button
        expect(page).to have_link('Download')

        # shows the rendered notebook
        expect(page).to have_content('test')
      end
    end
  end

  context 'ISO file (stored in LFS)' do
    context 'when LFS is enabled on the project' do
      before do
        allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)
        project.update_attribute(:lfs_enabled, true)

        visit_blob('files/lfs/lfs_object.iso')

        wait_for_requests
      end

      it 'displays the blob' do
        aggregate_failures do
          # shows a download link
          expect(page).to have_link('Download (1.5 MB)')

          # does not show a viewer switcher
          expect(page).not_to have_selector('.js-blob-viewer-switcher')

          # does not show a copy button
          expect(page).not_to have_selector('.js-copy-blob-source-btn')

          # shows a download button
          expect(page).to have_link('Download')
        end
      end
    end

    context 'when LFS is disabled on the project' do
      before do
        visit_blob('files/lfs/lfs_object.iso')

        wait_for_requests
      end

      it 'displays the blob' do
        aggregate_failures do
          # shows text
          expect(page).to have_content('size 1575078')

          # does not show a viewer switcher
          expect(page).not_to have_selector('.js-blob-viewer-switcher')

          # shows an enabled copy button
          expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')

          # shows a raw button
          expect(page).to have_link('Open raw')
        end
      end
    end
  end

  context 'ZIP file' do
    before do
      visit_blob('Gemfile.zip')

      wait_for_requests
    end

    it 'displays the blob' do
      aggregate_failures do
        # shows a download link
        expect(page).to have_link('Download (2.11 KB)')

        # does not show a viewer switcher
        expect(page).not_to have_selector('.js-blob-viewer-switcher')

        # does not show a copy button
        expect(page).not_to have_selector('.js-copy-blob-source-btn')

        # shows a download button
        expect(page).to have_link('Download')
      end
    end
  end

  context 'empty file' do
    before do
      project.add_maintainer(project.creator)

      Files::CreateService.new(
        project,
        project.creator,
        start_branch: 'master',
        branch_name: 'master',
        commit_message: "Add empty file",
        file_path: 'files/empty.md',
        file_content: ''
      ).execute

      visit_blob('files/empty.md')

      wait_for_requests
    end

    it 'displays an error' do
      aggregate_failures do
        # shows an error message
        expect(page).to have_content('Empty file')

        # does not show a viewer switcher
        expect(page).not_to have_selector('.js-blob-viewer-switcher')

        # does not show a copy button
        expect(page).not_to have_selector('.js-copy-blob-source-btn')

        # does not show a download or raw button
        expect(page).not_to have_link('Download')
        expect(page).not_to have_link('Open raw')
      end
    end
  end

  context 'binary file that appears to be text in the first 1024 bytes' do
    before do
      visit_blob('encoding/binary-1.bin', ref: 'binary-encoding')
    end

    it 'displays the blob' do
      aggregate_failures do
        # shows a download link
        expect(page).to have_link('Download (23.8 KB)')

        # does not show a viewer switcher
        expect(page).not_to have_selector('.js-blob-viewer-switcher')

        # The specs below verify an arguably incorrect result, but since we only
        # learn that the file is not actually text once the text viewer content
        # is loaded asynchronously, there is no straightforward way to get these
        # synchronously loaded elements to display correctly.
        #
        # Clicking the copy button will result in nothing being copied.
        # Clicking the raw button will result in the binary file being downloaded,
        # as expected.

        # shows an enabled copy button, incorrectly
        expect(page).to have_selector('.js-copy-blob-source-btn:not(.disabled)')

        # shows a raw button, incorrectly
        expect(page).to have_link('Open raw')
      end
    end
  end

  context 'files with auxiliary viewers' do
    before do
      stub_feature_flags(refactor_blob_viewer: true)
    end

    describe '.gitlab-ci.yml' do
      before do
        project.add_maintainer(project.creator)

        Files::CreateService.new(
          project,
          project.creator,
          start_branch: 'master',
          branch_name: 'master',
          commit_message: "Add .gitlab-ci.yml",
          file_path: '.gitlab-ci.yml',
          file_content: File.read(Rails.root.join('spec/support/gitlab_stubs/gitlab_ci.yml'))
        ).execute

        visit_blob('.gitlab-ci.yml')
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          # shows that configuration is valid
          expect(page).to have_content('This GitLab CI configuration is valid.')

          # shows a learn more link
          expect(page).to have_link('Learn more')
        end
      end
    end

    describe '.gitlab/route-map.yml' do
      before do
        project.add_maintainer(project.creator)

        Files::CreateService.new(
          project,
          project.creator,
          start_branch: 'master',
          branch_name: 'master',
          commit_message: "Add .gitlab/route-map.yml",
          file_path: '.gitlab/route-map.yml',
          file_content: <<-MAP.strip_heredoc
            # Team data
            - source: 'data/team.yml'
              public: 'team/'
          MAP
        ).execute

        visit_blob('.gitlab/route-map.yml')
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          # shows that map is valid
          expect(page).to have_content('This Route Map is valid.')

          # shows a learn more link
          expect(page).to have_link('Learn more')
        end
      end
    end

    describe '.gitlab/dashboards/custom-dashboard.yml' do
      before do
        project.add_maintainer(project.creator)

        Files::CreateService.new(
          project,
          project.creator,
          start_branch: 'master',
          branch_name: 'master',
          commit_message: "Add .gitlab/dashboards/custom-dashboard.yml",
          file_path: '.gitlab/dashboards/custom-dashboard.yml',
          file_content: file_content
        ).execute
      end

      context 'with metrics_dashboard_exhaustive_validations feature flag off' do
        before do
          stub_feature_flags(metrics_dashboard_exhaustive_validations: false)
          visit_blob('.gitlab/dashboards/custom-dashboard.yml')
        end

        context 'valid dashboard file' do
          let(:file_content) { File.read(Rails.root.join('config/prometheus/common_metrics.yml')) }

          it 'displays an auxiliary viewer' do
            aggregate_failures do
              # shows that dashboard yaml is valid
              expect(page).to have_content('Metrics Dashboard YAML definition is valid.')

              # shows a learn more link
              expect(page).to have_link('Learn more')
            end
          end
        end

        context 'invalid dashboard file' do
          let(:file_content) { "dashboard: 'invalid'" }

          it 'displays an auxiliary viewer' do
            aggregate_failures do
              # shows that dashboard yaml is invalid
              expect(page).to have_content('Metrics Dashboard YAML definition is invalid:')
              expect(page).to have_content("panel_groups: should be an array of panel_groups objects")

              # shows a learn more link
              expect(page).to have_link('Learn more')
            end
          end
        end
      end

      context 'with metrics_dashboard_exhaustive_validations feature flag on' do
        before do
          stub_feature_flags(metrics_dashboard_exhaustive_validations: true)
          visit_blob('.gitlab/dashboards/custom-dashboard.yml')
        end

        context 'valid dashboard file' do
          let(:file_content) { File.read(Rails.root.join('config/prometheus/common_metrics.yml')) }

          it 'displays an auxiliary viewer' do
            aggregate_failures do
              # shows that dashboard yaml is valid
              expect(page).to have_content('Metrics Dashboard YAML definition is valid.')

              # shows a learn more link
              expect(page).to have_link('Learn more')
            end
          end
        end

        context 'invalid dashboard file' do
          let(:file_content) { "dashboard: 'invalid'" }

          it 'displays an auxiliary viewer' do
            aggregate_failures do
              # shows that dashboard yaml is invalid
              expect(page).to have_content('Metrics Dashboard YAML definition is invalid:')
              expect(page).to have_content("root is missing required keys: panel_groups")

              # shows a learn more link
              expect(page).to have_link('Learn more')
            end
          end
        end
      end
    end

    context 'LICENSE' do
      before do
        visit_blob('LICENSE')
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          # shows license
          expect(page).to have_content('This project is licensed under the MIT License.')

          # shows a learn more link
          expect(page).to have_link('Learn more', href: 'http://choosealicense.com/licenses/mit/')
        end
      end
    end

    context '*.gemspec' do
      before do
        project.add_maintainer(project.creator)

        Files::CreateService.new(
          project,
          project.creator,
          start_branch: 'master',
          branch_name: 'master',
          commit_message: "Add activerecord.gemspec",
          file_path: 'activerecord.gemspec',
          file_content: <<-SPEC.strip_heredoc
            Gem::Specification.new do |s|
              s.platform    = Gem::Platform::RUBY
              s.name        = "activerecord"
            end
          SPEC
        ).execute

        visit_blob('activerecord.gemspec')
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          # shows names of dependency manager and package
          expect(page).to have_content('This project manages its dependencies using RubyGems.')

          # shows a learn more link
          expect(page).to have_link('Learn more', href: 'https://rubygems.org/')
        end
      end
    end

    context 'CONTRIBUTING.md' do
      before do
        file_name = 'CONTRIBUTING.md'

        create_file(file_name, '## Contribution guidelines')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("After you've reviewed these contribution guidelines, you'll be all set to contribute to this project.")
        end
      end
    end

    context 'CHANGELOG.md' do
      before do
        file_name = 'CHANGELOG.md'

        create_file(file_name, '## Changelog for v1.0.0')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("To find the state of this project's repository at the time of any of these versions, check out the tags.")
        end
      end
    end

    context 'Cargo.toml' do
      before do
        file_name = 'Cargo.toml'

        create_file(file_name, '
            [package]
            name = "hello_world" # the name of the package
            version = "0.1.0"    # the current version, obeying semver
            authors = ["Alice <a@example.com>", "Bob <b@example.com>"]
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using Cargo.")
        end
      end
    end

    context 'Cartfile' do
      before do
        file_name = 'Cartfile'

        create_file(file_name, '
            gitlab "Alamofire/Alamofire" == 4.9.0
            gitlab "Alamofire/AlamofireImage" ~> 3.4
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using Carthage.")
        end
      end
    end

    context 'composer.json' do
      before do
        file_name = 'composer.json'

        create_file(file_name, '
            {
              "license": "MIT"
            }
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using Composer.")
        end
      end
    end

    context 'Gemfile' do
      before do
        file_name = 'Gemfile'

        create_file(file_name, '
            source "https://rubygems.org"

            # Gems here
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using Bundler.")
        end
      end
    end

    context 'Godeps.json' do
      before do
        file_name = 'Godeps.json'

        create_file(file_name, '
            {
              "GoVersion": "go1.6"
            }
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using godep.")
        end
      end
    end

    context 'go.mod' do
      before do
        file_name = 'go.mod'

        create_file(file_name, '
            module example.com/mymodule

            go 1.14
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using Go Modules.")
        end
      end
    end

    context 'package.json' do
      before do
        file_name = 'package.json'

        create_file(file_name, '
            {
              "name": "my-awesome-package",
              "version": "1.0.0"
            }
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using npm.")
        end
      end
    end

    context 'podfile' do
      before do
        file_name = 'podfile'

        create_file(file_name, 'platform :ios, "8.0"')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using CocoaPods.")
        end
      end
    end

    context 'test.podspec' do
      before do
        file_name = 'test.podspec'

        create_file(file_name, '
            Pod::Spec.new do |s|
              s.name = "TensorFlowLiteC"
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using CocoaPods.")
        end
      end
    end

    context 'JSON.podspec.json' do
      before do
        file_name = 'JSON.podspec.json'

        create_file(file_name, '
            {
              "name": "JSON"
            }
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using CocoaPods.")
        end
      end
    end

    context 'requirements.txt' do
      before do
        file_name = 'requirements.txt'

        create_file(file_name, 'Project requirements')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using pip.")
        end
      end
    end

    context 'yarn.lock' do
      before do
        file_name = 'yarn.lock'

        create_file(file_name, '
            # THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.
            # yarn lockfile v1
          ')
        visit_blob(file_name)
      end

      it 'displays an auxiliary viewer' do
        aggregate_failures do
          expect(page).to have_content("This project manages its dependencies using Yarn.")
        end
      end
    end

    context 'when refactor_blob_viewer is disabled' do
      before do
        stub_feature_flags(refactor_blob_viewer: false)
      end

      describe '.gitlab-ci.yml' do
        before do
          project.add_maintainer(project.creator)

          Files::CreateService.new(
            project,
            project.creator,
            start_branch: 'master',
            branch_name: 'master',
            commit_message: "Add .gitlab-ci.yml",
            file_path: '.gitlab-ci.yml',
            file_content: File.read(Rails.root.join('spec/support/gitlab_stubs/gitlab_ci.yml'))
          ).execute

          visit_blob('.gitlab-ci.yml')
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            # shows that configuration is valid
            expect(page).to have_content('This GitLab CI configuration is valid.')

            # shows a learn more link
            expect(page).to have_link('Learn more')
          end
        end
      end

      describe '.gitlab/route-map.yml' do
        before do
          project.add_maintainer(project.creator)

          Files::CreateService.new(
            project,
            project.creator,
            start_branch: 'master',
            branch_name: 'master',
            commit_message: "Add .gitlab/route-map.yml",
            file_path: '.gitlab/route-map.yml',
            file_content: <<-MAP.strip_heredoc
              # Team data
              - source: 'data/team.yml'
                public: 'team/'
            MAP
          ).execute

          visit_blob('.gitlab/route-map.yml')
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            # shows that map is valid
            expect(page).to have_content('This Route Map is valid.')

            # shows a learn more link
            expect(page).to have_link('Learn more')
          end
        end
      end

      describe '.gitlab/dashboards/custom-dashboard.yml' do
        before do
          project.add_maintainer(project.creator)

          Files::CreateService.new(
            project,
            project.creator,
            start_branch: 'master',
            branch_name: 'master',
            commit_message: "Add .gitlab/dashboards/custom-dashboard.yml",
            file_path: '.gitlab/dashboards/custom-dashboard.yml',
            file_content: file_content
          ).execute
        end

        context 'with metrics_dashboard_exhaustive_validations feature flag off' do
          before do
            stub_feature_flags(metrics_dashboard_exhaustive_validations: false)
            visit_blob('.gitlab/dashboards/custom-dashboard.yml')
          end

          context 'valid dashboard file' do
            let(:file_content) { File.read(Rails.root.join('config/prometheus/common_metrics.yml')) }

            it 'displays an auxiliary viewer' do
              aggregate_failures do
                # shows that dashboard yaml is valid
                expect(page).to have_content('Metrics Dashboard YAML definition is valid.')

                # shows a learn more link
                expect(page).to have_link('Learn more')
              end
            end
          end

          context 'invalid dashboard file' do
            let(:file_content) { "dashboard: 'invalid'" }

            it 'displays an auxiliary viewer' do
              aggregate_failures do
                # shows that dashboard yaml is invalid
                expect(page).to have_content('Metrics Dashboard YAML definition is invalid:')
                expect(page).to have_content("panel_groups: should be an array of panel_groups objects")

                # shows a learn more link
                expect(page).to have_link('Learn more')
              end
            end
          end
        end

        context 'with metrics_dashboard_exhaustive_validations feature flag on' do
          before do
            stub_feature_flags(metrics_dashboard_exhaustive_validations: true)
            visit_blob('.gitlab/dashboards/custom-dashboard.yml')
          end

          context 'valid dashboard file' do
            let(:file_content) { File.read(Rails.root.join('config/prometheus/common_metrics.yml')) }

            it 'displays an auxiliary viewer' do
              aggregate_failures do
                # shows that dashboard yaml is valid
                expect(page).to have_content('Metrics Dashboard YAML definition is valid.')

                # shows a learn more link
                expect(page).to have_link('Learn more')
              end
            end
          end

          context 'invalid dashboard file' do
            let(:file_content) { "dashboard: 'invalid'" }

            it 'displays an auxiliary viewer' do
              aggregate_failures do
                # shows that dashboard yaml is invalid
                expect(page).to have_content('Metrics Dashboard YAML definition is invalid:')
                expect(page).to have_content("root is missing required keys: panel_groups")

                # shows a learn more link
                expect(page).to have_link('Learn more')
              end
            end
          end
        end
      end

      context 'LICENSE' do
        before do
          visit_blob('LICENSE')
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            # shows license
            expect(page).to have_content('This project is licensed under the MIT License.')

            # shows a learn more link
            expect(page).to have_link('Learn more', href: 'http://choosealicense.com/licenses/mit/')
          end
        end
      end

      context '*.gemspec' do
        before do
          project.add_maintainer(project.creator)

          Files::CreateService.new(
            project,
            project.creator,
            start_branch: 'master',
            branch_name: 'master',
            commit_message: "Add activerecord.gemspec",
            file_path: 'activerecord.gemspec',
            file_content: <<-SPEC.strip_heredoc
              Gem::Specification.new do |s|
                s.platform    = Gem::Platform::RUBY
                s.name        = "activerecord"
              end
            SPEC
          ).execute

          visit_blob('activerecord.gemspec')
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            # shows names of dependency manager and package
            expect(page).to have_content('This project manages its dependencies using RubyGems.')

            # shows a learn more link
            expect(page).to have_link('Learn more', href: 'https://rubygems.org/')
          end
        end
      end

      context 'CONTRIBUTING.md' do
        before do
          file_name = 'CONTRIBUTING.md'

          create_file(file_name, '## Contribution guidelines')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("After you've reviewed these contribution guidelines, you'll be all set to contribute to this project.")
          end
        end
      end

      context 'CHANGELOG.md' do
        before do
          file_name = 'CHANGELOG.md'

          create_file(file_name, '## Changelog for v1.0.0')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("To find the state of this project's repository at the time of any of these versions, check out the tags.")
          end
        end
      end

      context 'Cargo.toml' do
        before do
          file_name = 'Cargo.toml'

          create_file(file_name, '
              [package]
              name = "hello_world" # the name of the package
              version = "0.1.0"    # the current version, obeying semver
              authors = ["Alice <a@example.com>", "Bob <b@example.com>"]
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using Cargo.")
          end
        end
      end

      context 'Cartfile' do
        before do
          file_name = 'Cartfile'

          create_file(file_name, '
              gitlab "Alamofire/Alamofire" == 4.9.0
              gitlab "Alamofire/AlamofireImage" ~> 3.4
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using Carthage.")
          end
        end
      end

      context 'composer.json' do
        before do
          file_name = 'composer.json'

          create_file(file_name, '
              {
                "license": "MIT"
              }
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using Composer.")
          end
        end
      end

      context 'Gemfile' do
        before do
          file_name = 'Gemfile'

          create_file(file_name, '
              source "https://rubygems.org"

              # Gems here
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using Bundler.")
          end
        end
      end

      context 'Godeps.json' do
        before do
          file_name = 'Godeps.json'

          create_file(file_name, '
              {
                "GoVersion": "go1.6"
              }
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using godep.")
          end
        end
      end

      context 'go.mod' do
        before do
          file_name = 'go.mod'

          create_file(file_name, '
              module example.com/mymodule

              go 1.14
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using Go Modules.")
          end
        end
      end

      context 'package.json' do
        before do
          file_name = 'package.json'

          create_file(file_name, '
              {
                "name": "my-awesome-package",
                "version": "1.0.0"
              }
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using npm.")
          end
        end
      end

      context 'podfile' do
        before do
          file_name = 'podfile'

          create_file(file_name, 'platform :ios, "8.0"')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using CocoaPods.")
          end
        end
      end

      context 'test.podspec' do
        before do
          file_name = 'test.podspec'

          create_file(file_name, '
              Pod::Spec.new do |s|
                s.name = "TensorFlowLiteC"
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using CocoaPods.")
          end
        end
      end

      context 'JSON.podspec.json' do
        before do
          file_name = 'JSON.podspec.json'

          create_file(file_name, '
              {
                "name": "JSON"
              }
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using CocoaPods.")
          end
        end
      end

      context 'requirements.txt' do
        before do
          file_name = 'requirements.txt'

          create_file(file_name, 'Project requirements')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using pip.")
          end
        end
      end

      context 'yarn.lock' do
        before do
          file_name = 'yarn.lock'

          create_file(file_name, '
              # THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.
              # yarn lockfile v1
            ')
          visit_blob(file_name)
        end

        it 'displays an auxiliary viewer' do
          aggregate_failures do
            expect(page).to have_content("This project manages its dependencies using Yarn.")
          end
        end
      end
    end
  end

  context 'realtime pipelines' do
    before do
      Files::CreateService.new(
        project,
        project.creator,
        start_branch: 'feature',
        branch_name: 'feature',
        commit_message: "Add ruby file",
        file_path: 'files/ruby/test.rb',
        file_content: "# Awesome content"
      ).execute

      create(:ci_pipeline, status: 'running', project: project, ref: 'feature', sha: project.commit('feature').sha)
      visit_blob('files/ruby/test.rb', ref: 'feature')
    end

    it 'shows the realtime pipeline status' do
      page.within('.commit-actions') do
        expect(page).to have_css('.ci-status-icon')
        expect(page).to have_css('.ci-status-icon-running')
        expect(page).to have_css('.js-ci-status-icon-running')
      end
    end
  end

  context 'for subgroups' do
    let(:group) { create(:group) }
    let(:subgroup) { create(:group, parent: group) }
    let(:project) { create(:project, :public, :repository, group: subgroup) }

    it 'renders tree table without errors' do
      visit_blob('README.md')

      expect(page).to have_selector('.file-content')
      expect(page).not_to have_selector('.flash-alert')
    end

    it 'displays a GPG badge' do
      visit_blob('CONTRIBUTING.md', ref: '33f3729a45c02fc67d00adb1b8bca394b0e761d9')

      expect(page).not_to have_selector '.gpg-status-box.js-loading-gpg-badge'
      expect(page).to have_selector '.gpg-status-box.invalid'
    end
  end

  context 'on signed merge commit' do
    it 'displays a GPG badge' do
      visit_blob('conflicting-file.md', ref: '6101e87e575de14b38b4e1ce180519a813671e10')

      expect(page).not_to have_selector '.gpg-status-box.js-loading-gpg-badge'
      expect(page).to have_selector '.gpg-status-box.invalid'
    end
  end

  context 'when static objects external storage is enabled' do
    before do
      stub_application_setting(static_objects_external_storage_url: 'https://cdn.gitlab.com')
    end

    context 'private project' do
      let_it_be(:project) { create(:project, :repository, :private) }
      let_it_be(:user) { create(:user) }

      before do
        project.add_developer(user)

        sign_in(user)
        visit_blob('README.md')
      end

      it 'shows open raw and download buttons with external storage URL prepended and user token appended to their href' do
        path = project_raw_path(project, 'master/README.md')
        raw_uri = "https://cdn.gitlab.com#{path}?token=#{user.static_object_token}"
        download_uri = "https://cdn.gitlab.com#{path}?inline=false&token=#{user.static_object_token}"

        aggregate_failures do
          expect(page).to have_link 'Open raw', href: raw_uri
          expect(page).to have_link 'Download', href: download_uri
        end
      end
    end

    context 'public project' do
      before do
        visit_blob('README.md')
      end

      it 'shows open raw and download buttons with external storage URL prepended to their href' do
        path = project_raw_path(project, 'master/README.md')
        raw_uri = "https://cdn.gitlab.com#{path}"
        download_uri = "https://cdn.gitlab.com#{path}?inline=false"

        aggregate_failures do
          expect(page).to have_link 'Open raw', href: raw_uri
          expect(page).to have_link 'Download', href: download_uri
        end
      end
    end
  end
end
