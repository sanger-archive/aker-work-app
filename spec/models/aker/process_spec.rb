require 'rails_helper'

RSpec.describe Aker::Process, type: :model do
  describe "#validation" do
    it 'is not valid without a name' do
      expect(build(:aker_process, name: nil)).to_not be_valid
    end

    it 'is not valid without a uuid' do
      expect(build(:aker_process, uuid: nil)).to_not be_valid
    end

    it 'is not valid without a TAT' do
      expect(build(:aker_process, TAT: nil)).to_not be_valid
    end

    it 'is valid with required fields' do
      expect(build(:aker_process)).to be_valid
    end
  end

  describe 'process description' do
    def build_linear_process_for(process, size)
      modules = size.times.map {|pos| create :aker_process_module,  aker_process: process }
      list_of_modules = modules.clone
      from_process = modules.shift
      modules.map do |to_process|
        create(:aker_process_module_pairings, 
          from_step: from_process, to_step: to_process, aker_process: process, default_path: false)  
        from_process = to_process
      end

      # start
      create(:aker_process_module_pairings, 
          from_step: nil, to_step: list_of_modules.first, aker_process: process, default_path: false)  

      # end 
      create(:aker_process_module_pairings, 
          from_step: list_of_modules.last, to_step: nil, aker_process: process, default_path: false)  

      list_of_modules
    end

    context '#build_available_links' do

      context 'with an empty list of pairings' do
        it 'returns an empty object' do
          process = create :process
          expect(process.build_available_links).to eq({})
        end
      end

      context 'with a linear process' do
        before do
          @process = create :process
          @list_of_modules = build_linear_process_for(@process, 5)
        end
        it 'creates an object describing that linear process' do
          expect(@process.build_available_links).to eq(
            "start" => [{:name => @list_of_modules[0].name, :id => @list_of_modules[0].id}],
            @list_of_modules[0].name => [@list_of_modules[1].to_custom_hash],
            @list_of_modules[1].name => [@list_of_modules[2].to_custom_hash],
            @list_of_modules[2].name => [@list_of_modules[3].to_custom_hash],
            @list_of_modules[3].name => [@list_of_modules[4].to_custom_hash],
            @list_of_modules[4].name => [{:name => "end"}]
          )
        end
      end

      context 'with diferent processes structures' do
        context 'with a loop process' do
          before do
            @process = create :process
            @list_of_modules = build_linear_process_for(@process, 5)
            create(:aker_process_module_pairings, 
              from_step: @list_of_modules.last, 
              to_step: @list_of_modules.first, 
              aker_process: @process, 
              default_path: false)
          end
          it 'creates an object describing the loop' do
            expect(@process.build_available_links).to eq(
              "start" => [{:name => @list_of_modules[0].name, :id => @list_of_modules[0].id}],
              @list_of_modules[0].name => [@list_of_modules[1].to_custom_hash],
              @list_of_modules[1].name => [@list_of_modules[2].to_custom_hash],
              @list_of_modules[2].name => [@list_of_modules[3].to_custom_hash],
              @list_of_modules[3].name => [@list_of_modules[4].to_custom_hash],
              @list_of_modules[4].name => [{:name => "end"}, @list_of_modules[0].to_custom_hash]
            )
          end
        end
        context 'with 2 parallel linear modules not connected' do
          before do
            @process = create :process
            @list_of_modules = build_linear_process_for(@process, 2)
            @list_of_modules2 = build_linear_process_for(@process, 2)
          end
          it 'creates an object describing these with 2 starting points and 2 ending' do
            expect(@process.build_available_links).to eq({
              "start" => [
                  @list_of_modules[0].to_custom_hash, 
                  @list_of_modules2[0].to_custom_hash
                ],
              @list_of_modules[0].name => [@list_of_modules[1].to_custom_hash],
              @list_of_modules2[0].name => [@list_of_modules2[1].to_custom_hash],
              @list_of_modules[1].name => [{:name => "end"}],
              @list_of_modules2[1].name => [{:name => "end"}]
            })
          end
        end
        context 'with some parallel linear modules interconnected' do
          before do
            @process = create :process
            @list_of_modules = build_linear_process_for(@process, 2)
            @list_of_modules2 = build_linear_process_for(@process, 2)
            @list_of_modules3 = build_linear_process_for(@process, 2)

            create(:aker_process_module_pairings, 
              from_step: @list_of_modules[0], 
              to_step: @list_of_modules2[1], 
              aker_process: @process, 
              default_path: false)
            create(:aker_process_module_pairings, 
              from_step: @list_of_modules2[0], 
              to_step: @list_of_modules[1], 
              aker_process: @process, 
              default_path: false)          

          end
          it 'creates an object describing these with starting points and endings, and connections between' do
            expect(@process.build_available_links).to eq({
              "start" => [
                  @list_of_modules[0].to_custom_hash, 
                  @list_of_modules2[0].to_custom_hash,
                  @list_of_modules3[0].to_custom_hash
                ],
              @list_of_modules[0].name => [
                @list_of_modules[1].to_custom_hash,
                @list_of_modules2[1].to_custom_hash
                ],
              @list_of_modules2[0].name => [
                @list_of_modules2[1].to_custom_hash,
                @list_of_modules[1].to_custom_hash
              ],
              @list_of_modules3[0].name => [
                @list_of_modules3[1].to_custom_hash],

              @list_of_modules[1].name => [{:name => "end"}],
              @list_of_modules2[1].name => [{:name => "end"}],
              @list_of_modules3[1].name => [{:name => "end"}]
            })
          end
        end

      end
    end

    context '#build_default_path' do
      context 'a linear process' do
        before do
          @process = create :process
          @list_of_modules = build_linear_process_for(@process, 5)
          Aker::ProcessModulePairings.all.update_all(default_path: true)          
        end
        it 'gets the default path' do
          expect(@process.build_default_path).to eq(@list_of_modules.map(&:to_custom_hash))
        end
      end

      context 'with some parallel linear modules interconnected' do
        before do
          @process = create :process
          @list_of_modules = build_linear_process_for(@process, 2)
          @list_of_modules2 = build_linear_process_for(@process, 2)
          @list_of_modules3 = build_linear_process_for(@process, 2)

          create(:aker_process_module_pairings, 
            from_step: @list_of_modules[0], 
            to_step: @list_of_modules2[1], 
            aker_process: @process, 
            default_path: true)
          create(:aker_process_module_pairings, 
            from_step: @list_of_modules2[0], 
            to_step: @list_of_modules[1], 
            aker_process: @process, 
            default_path: false)

          Aker::ProcessModulePairings.where(to_step: @list_of_modules[0]).update_all(default_path: true)
          Aker::ProcessModulePairings.where(from_step: @list_of_modules[0], to_step: @list_of_modules2[1]).update_all(default_path: true)
          Aker::ProcessModulePairings.where(from_step: @list_of_modules2[1]).update_all(default_path: true)
        end
        it 'gets the default path' do
          expect(@process.build_default_path).to eq([@list_of_modules[0].to_custom_hash, @list_of_modules2[1].to_custom_hash])
        end
      end
    end
  end
end