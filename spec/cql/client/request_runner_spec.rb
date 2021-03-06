# encoding: utf-8

require 'spec_helper'


module Cql
  module Client
    describe RequestRunner do
      let :runner do
        described_class.new
      end

      let :connection do
        stub(:connection)
      end

      let :request do
        stub(:request)
      end

      let :metadata do
        [
          ['my_keyspace', 'my_table', 'my_column', :int],
          ['my_keyspace', 'my_table', 'my_other_column', :text],
        ]
      end

      let :rows do
        [
          {'my_column' => 11, 'my_other_column' => 'hello'},
          {'my_column' => 22, 'my_other_column' => 'foo'},
          {'my_column' => 33, 'my_other_column' => 'bar'},
        ]
      end

      describe '#execute' do
        let :rows_response do
          Protocol::RowsResultResponse.new(rows, metadata)
        end

        let :void_response do
          Protocol::VoidResultResponse.new
        end

        let :prepared_response do
          Protocol::PreparedResultResponse.new("\x2a", metadata)
        end

        let :error_response do
          Protocol::ErrorResponse.new(0xbad, 'Bork')
        end

        let :authenticate_response do
          Protocol::AuthenticateResponse.new('TheAuthenticator')
        end

        let :set_keyspace_response do
          Protocol::SetKeyspaceResultResponse.new('some_keyspace')
        end

        def run(response, rq=request)
          connection.stub(:send_request).and_return(Future.completed(response))
          runner.execute(connection, rq).get
        end

        it 'executes the request' do
          connection.should_receive(:send_request).and_return(Future.completed(rows_response))
          runner.execute(connection, request)
        end

        it 'transforms a RowsResultResponse to a query result' do
          result = run(rows_response)
          result.should have(3).items
        end

        it 'transforms a VoidResultResponse to nil' do
          result = run(void_response)
          result.should be_nil
        end

        it 'transforms a PreparedResultResponse to a prepared statement' do
          result = run(prepared_response)
          result.should be_a(AsynchronousPreparedStatement)
          result.metadata['my_column'].should == ColumnMetadata.new('my_keyspace', 'my_table', 'my_column', :int)
        end

        it 'transforms a AuthenticateResponse to an authentication required object' do
          result = run(authenticate_response)
          result.should be_a(AuthenticationRequired)
          result.authentication_class.should == 'TheAuthenticator'
        end

        it 'transforms a SetKeyspaceResultResponse into a keyspace changed object' do
          result = run(set_keyspace_response)
          result.should be_a(KeyspaceChanged)
          result.keyspace.should == 'some_keyspace'
        end

        it 'intercepts an ErrorResponse and fails the result future' do
          expect { run(error_response) }.to raise_error(QueryError)
        end

        it 'sets the #cql field of QueryError when the request is a query request' do
          begin
            run(error_response, Protocol::QueryRequest.new('SELECT * FROM everything', :all))
          rescue QueryError => e
            e.cql.should == 'SELECT * FROM everything'
          else
            fail!('No error was raised')
          end
        end

        it 'transforms all other responses to nil' do
          result = run('hibbly hobbly')
          result.should be_nil
        end
      end
    end
  end
end