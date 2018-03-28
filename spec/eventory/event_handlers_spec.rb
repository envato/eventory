RSpec.describe Eventory::EventHandlers do
  subject(:event_handlers) { Eventory::EventHandlers.new }

  describe '#add' do
    it 'stores the block keyed on the event class' do
      event_handlers.add('EventClassOne', 'block 1')
      event_handlers.add('EventClassOne', 'block 2')
      event_handlers.add('EventClassTwo', 'block 3')

      expect(event_handlers.for('EventClassOne')).to eq ['block 1', 'block 2']
      expect(event_handlers.for('EventClassTwo')).to eq ['block 3']
    end
  end

  describe '#for' do
    it 'returns the events for the class' do
      event_handlers.add('EventClassOne', 'block 1')
      event_handlers.add('EventClassOne', 'block 2')
      event_handlers.add('EventClassTwo', 'block 3')

      expect(event_handlers.for('EventClassOne')).to eq ['block 1', 'block 2']
      expect(event_handlers.for('EventClassTwo')).to eq ['block 3']
    end
  end

  describe '#handled_event_classes' do
    before do
      event_handlers.add('EventClassOne', 'block 1')
      event_handlers.add('EventClassOne', 'block 2')
      event_handlers.add('EventClassTwo', 'block 3')
    end

    it 'returns the handled event classes' do
      expect(event_handlers.handled_event_classes).to eq ['EventClassOne', 'EventClassTwo']
    end

    context 'when an unknown event is accessed' do
      it 'does not modify the stored event classes' do
        event_handlers.for('EventClassThree')

        expect(event_handlers.handled_event_classes).to eq ['EventClassOne', 'EventClassTwo']
      end
    end
  end
end
