require 'spec_helper'

RSpec.describe 'filtering' do
  include_context 'resource testing'
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name;'PORO::EmployeeResource';end
    end
  end
  let(:base_scope) { { type: :employees, conditions: {} } }

  let!(:employee1) do
    PORO::Employee.create(first_name: 'Stephen', last_name: 'King')
  end
  let!(:employee2) do
    PORO::Employee.create(first_name: 'Agatha', last_name: 'Christie')
  end
  let!(:employee3) do
    PORO::Employee.create(first_name: 'William', last_name: 'Shakesphere')
  end
  let!(:employee4) do
    PORO::Employee.create(first_name: 'Harold',  last_name: 'Robbins')
  end

  it 'scopes correctly' do
    params[:filter] = { id: { eq: employee1.id } }
    expect(records.map(&:id)).to eq([employee1.id])
  end

  context 'when only allowing single values' do
    before do
      resource.filter :first_name, :string, single: true do
        eq do |scope, value|
          scope[:conditions].merge!(first_name: value)
          scope
        end
      end
    end

    it 'rejects multiples' do
      params[:filter] = { first_name: { eq: 'William,Harold' } }
      expect {
        records
      }.to raise_error(Graphiti::Errors::SingularFilter, /passed multiple values to filter :first_name/)
    end

    it 'allows singles' do
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    it 'yields a singular value' do
      expect(PORO::DB).to receive(:all)
        .with(hash_including(conditions: { first_name: 'William' }))
        .and_call_original
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    context 'and whitelisting inputs' do
      before do
        resource.config[:filters] = {}
        resource.filter :first_name, :string, single: true, allow: ['William'] do
          eq do |scope, value|
            scope[:conditions].merge!(first_name: value)
            scope
          end
        end
      end

      it 'rejects values not in the whitelist' do
        params[:filter] = { first_name: { eq: 'Harold' } }
        expect {
          records
        }.to raise_error( Graphiti::Errors::InvalidFilterValue, /Whitelist: \[\"William\"\]/)
      end

      it 'accepts values in the whitelist' do
        params[:filter] = { first_name: { eq: 'William' } }
        expect(records.map(&:id)).to eq([employee3.id])
      end
    end

    context 'and blacklisting inputs' do
      before do
        resource.config[:filters] = {}
        resource.filter :first_name, :string, single: true, reject: ['Harold'] do
          eq do |scope, value|
            scope[:conditions].merge!(first_name: value)
            scope
          end
        end
      end

      it 'rejects values in the blacklist' do
        params[:filter] = { first_name: { eq: 'Harold' } }
        expect {
          records
        }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Blacklist: \[\"Harold\"\]/)
      end

      it 'accepts values not in the blacklist' do
        params[:filter] = { first_name: { eq: 'William' } }
        expect(records.map(&:id)).to eq([employee3.id])
      end
    end
  end

  context 'when whitelisting inputs' do
    before do
      resource.config[:filters] = {}
      resource.filter :first_name, :string, allow: ['William', 'Agatha'] do
        eq do |scope, value|
          scope[:conditions].merge!(first_name: value)
          scope
        end
      end
    end

    it 'rejects values not in the whitelist' do
      params[:filter] = { first_name: { eq: 'Harold' } }
      expect {
        records
      }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Whitelist: \["William", "Agatha"\]/)
    end

    it 'accepts values in the whitelist' do
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    context 'and passed an array' do
      context 'where one value is not whitelisted' do
        before do
          params[:filter] = { first_name: { eq: ['Harold', 'William'] } }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Whitelist: \["William", "Agatha"\]/)
        end
      end

      context 'where all values are in whitelist' do
        before do
          params[:filter] = { first_name: { eq: ['Agatha', 'William'] } }
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee2.id, employee3.id])
        end
      end
    end
  end

  context 'when blacklisting inputs' do
    before do
      resource.config[:filters] = {}
      resource.filter :first_name, :string, reject: ['Harold'] do
        eq do |scope, value|
          scope[:conditions].merge!(first_name: value)
          scope
        end
      end
    end

    it 'rejects values in the blacklist' do
      params[:filter] = { first_name: { eq: 'Harold' } }
      expect {
        records
      }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Blacklist: \[\"Harold\"\]/)
    end

    it 'accepts values not in the blacklist' do
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    context 'and passed an array' do
      context 'where one value is in the blacklist' do
        before do
          params[:filter] = { first_name: { eq: ['Harold', 'William'] } }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Blacklist: \["Harold"\]/)
        end
      end

      context 'where no values are in the blacklist' do
        before do
          params[:filter] = { first_name: { eq: ['Agatha', 'William'] } }
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee2.id, employee3.id])
        end
      end
    end
  end

  context 'when boolean filter' do
    before do
      resource.filter :active, :boolean
    end

    it 'is single by default' do
      expect(resource.filters[:active][:single]).to eq(true)
    end
  end

  # NB: even though query params are always strings, I'd like to
  # support vanilla query interface coercions as well.
  # Which is why you see tests for it.
  describe 'types' do
    def assert_filter_value(value)
      expect(PORO::DB).to receive(:all)
        .with(hash_including(conditions: { foo: value }))
        .and_return([])
      records
    end

    context 'when integer_id' do
      before do
        resource.attribute :foo, :integer_id
      end

      it 'queries via integer' do
        params[:filter] = { foo: '1' }
        assert_filter_value([1])
      end
    end

    context 'when string' do
      before do
        resource.attribute :foo, :string
      end

      it 'coerces' do
        params[:filter] = { foo: 1 }
        assert_filter_value(['1'])
      end
    end

    context 'when integer' do
      before do
        resource.attribute :foo, :integer
      end

      it 'coerces' do
        params[:filter] = { foo: '1' }
        assert_filter_value([1])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when decimal' do
      before do
        resource.attribute :foo, :big_decimal
      end

      it 'coerces integers' do
        params[:filter] = { foo: 40 }
        assert_filter_value([BigDecimal.new(40)])
      end

      it 'coerces strings' do
        params[:filter] = { foo: '40.01' }
        assert_filter_value([BigDecimal('40.01')])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        # NB ArgumentError not TypeError
        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when float' do
      before do
        resource.attribute :foo, :float
      end

      it 'coerces strings' do
        params[:filter] = { foo: '40.01' }
        assert_filter_value([40.01])
      end

      it 'coerces integers' do
        params[:filter] = { foo: '40' }
        assert_filter_value([40.0])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        # NB ArgumentError
        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when boolean' do
      before do
        resource.attribute :foo, :boolean
      end

      it 'coerces string true' do
        params[:filter] = { foo: 'true' }
        assert_filter_value(true)
      end

      it 'coerces string false' do
        params[:filter] = { foo: 'false' }
        assert_filter_value(false)
      end

      it 'coerces true integers' do
        params[:filter] = { foo: 1 }
        assert_filter_value(true)
      end

      it 'coerces false integers' do
        params[:filter] = { foo: 0 }
        assert_filter_value(false)
      end

      it 'coerces string true integers' do
        params[:filter] = { foo: '1' }
        assert_filter_value(true)
      end

      it 'coerces string false integers' do
        params[:filter] = { foo: '0' }
        assert_filter_value(false)
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value(nil)
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'asdf' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when date' do
      before do
        resource.attribute :foo, :date
      end

      it 'coerces Date to correct string format' do
        params[:filter] = { foo: '2018/01/06' }
        assert_filter_value([Date.parse('2018-01-06')])
      end

      it 'coerces Time to correct date string format' do
        params[:filter] = { foo: Time.now.iso8601 }
        assert_filter_value([Date.today])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when only month' do
        before do
          params[:filter] = { foo: '2018-01' }
        end

        it 'raises error because that is not a date' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when datetime' do
      before do
        resource.attribute :foo, :datetime
      end

      it 'coerces strings correctly' do
        params[:filter] = { foo: '2018-01-01 4:36pm PST' }
        time = Time.parse('2018-01-01 16:36:00.000000000 -0800')
        assert_filter_value([time])
      end

      it 'coerces iso8601 strings correctly' do
        time = Time.parse('2018-01-06 4:36pm PST')
        params[:filter] = { foo: time.iso8601 }
        assert_filter_value([time])
      end

      it 'coerces Date correctly' do
        params[:filter] = { foo: '2018-01-06' }
        assert_filter_value([DateTime.parse('2018-01-06')])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when hash' do
      before do
        resource.attribute :foo, :hash
      end

      it 'works' do
        params[:filter] = { foo: { eq: { bar: 'baz' } } }
        assert_filter_value([{ bar: 'baz' }])
      end

      context 'when stringified keys' do
        before do
          params[:filter] = {
            'foo' => {
              'eq' => {
                'bar' => {
                  'baz' => 'blah'
                }
              }
            }
          }
        end

        it 'converts to symbolized keys' do
          assert_filter_value([{ bar: { baz: 'blah' } }])
        end
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: { eq: 'bar' } }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when array' do
      before do
        resource.attribute :foo, :array
      end

      it 'works for arrays' do
        params[:filter] = { foo: [1, 2] }
        assert_filter_value([1, 2])
      end

      it 'works for string arrays' do
        params[:filter] = { foo: '1,2' }
        assert_filter_value(['1', '2'])
      end

      # If we did Array(value), you'd get something incorrect
      # for hashes
      it 'raises error on single values' do
        params[:filter] = { foo: 1 }
        expect {
          records
        }.to raise_error(Graphiti::Errors::TypecastFailed)
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    # test for all array_of_*
    context 'when array_of_integers' do
      before do
        resource.attribute :foo, :array_of_integers
      end

      it 'works' do
        params[:filter] = { foo: [1, 2, 3] }
        assert_filter_value([1, 2, 3])
      end

      it 'applies basic coercion of elements' do
        params[:filter] = { foo: ['1', '2', '3'] }
        assert_filter_value([1, 2, 3])
      end

      # If we did Array(value), you'd get something incorrect
      # for hashes
      it 'raises error on single values' do
        params[:filter] = { foo: 1 }
        expect {
          records
        }.to raise_error(Graphiti::Errors::TypecastFailed)
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: '' }
        end

        it 'raises error' do
          expect {
            render
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when custom type' do
      before do
        type = Dry::Types::Definition
          .new(nil)
          .constructor { |input|
            'custom!'
          }
        Graphiti::Types[:custom] = {
          params: type,
          canonical_name: :string,
          read: type,
          write: type,
          kind: 'scalar',
          description: 'test'
        }
        resource.attribute :foo, :custom
      end

      after do
        Graphiti::Types.map.delete(:custom)
      end

      it 'works' do
        params[:filter] = { foo: '1' }
        assert_filter_value(['custom!'])
      end
    end
  end

  context 'when custom filtering' do
    context 'and the attribute exists' do
      before do
        _2 = employee2.id
        resource.attribute :foo, :string
        resource.filter :foo do
          eq do |scope, value|
            scope[:conditions][:id] = _2
            scope
          end
        end
      end

      it 'is correctly applied' do
        params[:filter] = { foo: 'bar' }
        expect(records.map(&:id)).to eq([employee2.id])
      end

      it 'adds a list of default operators' do
        expect(resource.filters[:foo][:operators].keys).to eq([
          :eq,
          :not_eq,
          :eql,
          :not_eql,
          :prefix,
          :not_prefix,
          :suffix,
          :not_suffix,
          :match,
          :not_match
        ])
        expect(resource.filters[:foo][:operators][:eq]).to be_a(Proc)
        expect(resource.filters[:foo][:operators][:suffix]).to be_nil
      end

      context 'but it is not filterable' do
        before do
          resource.attributes[:foo][:filterable] = false
        end

        it 'raises helpful error' do
          expect {
            resource.filter :foo do
            end
          }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to add filter attribute :foo, but the attribute was marked :filterable => false.')
        end
      end
    end

    context 'and the attribute does not exist' do
      before do
        _2 = employee2.id
        resource.filter :foo, :string do
          eq do |scope, value|
            scope[:conditions][:id] = _2
            scope
          end
        end
        params[:filter] = { foo: 'bar' }
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end

      it 'adds an only: [:filterable] attribute' do
        att = resource.attributes[:foo]
        expect(att[:readable]).to eq(false)
        expect(att[:writable]).to eq(false)
        expect(att[:sortable]).to eq(false)
        expect(att[:filterable]).to eq(true)
        expect(att[:type]).to eq(:string)
      end

      context 'when no type given' do
        before do
          resource.attributes.delete(:foo)
        end

        it 'blows up' do
          expect {
            resource.filter :foo do
            end
          }.to raise_error(Graphiti::Errors::ImplicitFilterTypeMissing)
        end
      end
    end

    context 'and given :only option' do
      context 'and the attribute already exists' do
        before do
          resource.attribute :foo, :string
          resource.filter :foo, only: [:eq] do
            foo do
            end
          end
        end

        it 'limits available operators' do
          expect(resource.filters[:foo][:operators].keys).to eq([:eq, :foo])
        end
      end

      context 'and no attribute already exists' do
        before do
          resource.filter :foo, :string, only: [:eq] do
            foo do
            end
          end
        end

        it 'limits available operators, adding custom ones' do
          expect(resource.filters[:foo][:operators].keys).to eq([:eq, :foo])
        end
      end
    end

    context 'and given :except option' do
      context 'and the attribute already exists' do
        before do
          resource.attribute :foo, :integer
          resource.filter :foo, except: [:eq, :not_eq] do
            foo do
            end
          end
        end

        it 'limits available operators' do
          expect(resource.filters[:foo][:operators].keys).to eq([
            :gt, :gte, :lt, :lte, :foo
          ])
        end
      end

      context 'and no attribute already exists' do
        before do
          resource.filter :foo, :integer, except: [:eq, :not_eq] do
            foo do
            end
          end
        end

        it 'limits available operators, adding custom ones' do
          expect(resource.filters[:foo][:operators].keys).to eq([
            :gt, :gte, :lt, :lte, :foo
          ])
        end
      end
    end
  end

  context 'when filtering based on calling context' do
    around do |e|
      Graphiti.with_context(OpenStruct.new(runtime_id: employee3.id)) do
        e.run
      end
    end

    before do
      resource.attribute :foo, :boolean
      resource.filter :foo do
        eq do |scope, value, ctx|
          scope[:conditions][:id] = ctx.runtime_id
          scope
        end
      end
      params[:filter] = { foo: true }
    end

    it 'has access to calling context' do
      expect(records.map(&:id)).to eq([employee3.id])
    end
  end

  context 'when running an implicit attribute filter' do
    before do
      resource.attribute :active, :boolean
    end

    it 'works' do
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
      expect(records.map(&:id)).to eq([employee1.id, employee3.id, employee4.id])
    end
  end

  context 'when filter is a "string boolean"' do
    before do
      resource.attribute :active, :boolean
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
    end

    it 'automatically casts to a real boolean' do
      ids = records.map(&:id)
      expect(ids.length).to eq(3)
      expect(ids).to_not include(employee2.id)
    end
  end

  context 'when filter is an integer' do
    before do
      params[:filter] = { id: employee1.id }
    end

    it 'still works' do
      expect(records.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when customized with alternate param name' do
    before do
      params[:filter] = { name: 'Stephen' }
    end

    xit 'filters based on the correct name' do
      expect(records.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when the supplied value is comma-delimited' do
    before do
      params[:filter] = { id: [employee1.id, employee2.id].join(',') }
    end

    it 'parses into a ruby array' do
      expect(records.map(&:id)).to eq([employee1.id, employee2.id])
    end
  end

  context 'when a default filter' do
    before do
      resource.class_eval do
        default_filter :first_name do |scope|
          scope[:conditions].merge!(first_name: 'William')
          scope
        end
      end
    end

    it 'applies by default' do
      expect(records.map(&:id)).to eq([employee3.id])
    end

    it 'is overrideable' do
      params[:filter] = { first_name: 'Stephen' }
      expect(records.map(&:id)).to eq([employee1.id])
    end

    context 'without an attribute name' do
      before do
        resource.default_filter do |scope|
          scope[:conditions].merge!(first_name: 'Agatha')
          scope
        end
      end

      it 'is allowed' do
        expect(records.map(&:id)).to eq([employee2.id])
        expect(resource.default_filters[:__default]).to be_present
      end
    end

    xit "is overrideable when overriding via an allowed filter's alias" do
      params[:filter] = { name: 'Stephen' }
      expect(records.map(&:id)).to eq([employee1.id])
    end

    context 'when accessing calling context' do
      before do
        resource.class_eval do
          default_filter :first_name do |scope, ctx|
            scope[:conditions].merge!(id: ctx.runtime_id)
            scope
          end
        end
      end

      it 'works' do
        ctx = double(runtime_id: employee3.id).as_null_object
        Graphiti.with_context(ctx, {}) do
          expect(records.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when filtering on an unknown attribute' do
    before do
      params[:filter] = { foo: 'bar' }
    end

    it 'raises helpful error' do
      expect {
        records
      }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to filter on attribute :foo, but could not find an attribute with that name.')
    end

    context 'but there is a corresponding extra attribute' do
      before do
        resource.extra_attribute :foo, :string
      end

      context 'but it is not filterable' do
        it 'raises helpful error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to filter on attribute :foo, but the attribute was marked :filterable => false.')
        end
      end

      context 'and it is filterable' do
        before do
          resource.extra_attribute :foo, :string, filterable: true
          _3 = employee3.id
          resource.filter :foo do
            eq do |scope, value|
              scope[:conditions] = { id: _3 }
              scope
            end
          end
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when filter is guarded' do
    before do
      resource.class_eval do
        attribute :first_name, :string, filterable: :admin?

        def admin?
          !!context.admin
        end
      end
      params[:filter] = { first_name: 'Agatha' }
    end

    context 'and the guard passes' do
      around do |e|
        Graphiti.with_context(OpenStruct.new(admin: true)) do
          e.run
        end
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'and the guard fails' do
      around do |e|
        Graphiti.with_context(OpenStruct.new(admin: false)) do
          e.run
        end
      end

      it 'raises helpful error' do
        expect {
          records
        }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to filter on attribute :first_name, but the guard :admin? did not pass.')
      end
    end
  end

  context 'when filter is required' do
    before do
      resource.attribute :first_name, :string, filterable: :required
    end

    context 'and given in the request' do
      before do
        params[:filter] = { first_name: 'Agatha' }
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'but not given in request' do
      it 'raises error' do
        expect {
          records
        }.to raise_error(Graphiti::Errors::RequiredFilter)
      end
    end
  end

  context 'when > 1 filter required' do
    before do
      resource.attribute :first_name, :string, filterable: :required
      resource.attribute :last_name, :string, filterable: :required
    end

    context 'but not given in request' do
      it 'raises error that lists all unsupplied filters' do
        expect {
          records
        }.to raise_error(/The required filters "first_name, last_name"/)
      end
    end
  end
end
