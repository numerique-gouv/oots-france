module Admin
  module Journal
    # The files a Commission test case expects of one execution, drawn from a
    # conversation's journal and served in one zip archive.
    #
    # Always an attachment, and never a part on its own under the type a
    # correspondent declared for it: offering bytes a third party chose under
    # their own MIME type would open a surface nothing asks for.
    class TestFilesController < BaseController
      include ReadsConversation

      def show
        read_conversation(params.expect(:conversation_id), test_run: TestRun.from(params))

        # The form is not offered where there is nothing to download, so only a
        # forged address arrives here: answered like a conversation nobody named.
        raise ActiveRecord::RecordNotFound if @test_files.none?

        if @test_run.invalid?
          render 'admin/journal/conversations/show', status: :unprocessable_content
        else
          send_data TestFilesArchiveBuilder.new(@test_files).build,
            type: 'application/zip', disposition: :attachment, filename: @test_files.archive_name
        end
      end
    end
  end
end
