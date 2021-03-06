require 'rails_helper'

describe PageChange do

  before(:each) do

  end

  describe 'get_by_id' do

    it 'gets by id' do
      change = create :page_change

      result = PageChange.get_by_id change.id

      expect(result).to eq(change)
    end

    it 'gets by id with no id' do
      change = create :page_change

      result = PageChange.get_by_id nil

      expect(result).to be_nil
    end

  end

  describe 'gets diff' do

    it 'diffs 2 contents' do
      result = PageChange.get_diff('== Title1 ==', '== Title2 ==')

      expect(result).to eq('== Title<del class="differ">2</del><ins class="differ">1</ins> ==')
    end

  end

end
