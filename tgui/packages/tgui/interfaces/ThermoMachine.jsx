import { toFixed } from 'common/math';

import { useBackend } from '../backend';
import {
  AnimatedNumber,
  Button,
  LabeledList,
  NumberInput,
  Section,
} from '../components';
import { Window } from '../layouts';

export const ThermoMachine = (props) => {
  const { act, data } = useBackend();
  return (
    <Window width={300} height={350}>
      <Window.Content>
        <Section title="Status" crtFitted>
          <LabeledList>
            <LabeledList.Item label="Temperature">
              <AnimatedNumber
                value={data.temperature}
                format={(value) => toFixed(value, 2)}
              />
              {' K'}
            </LabeledList.Item>
            <LabeledList.Item label="Pressure">
              <AnimatedNumber
                value={data.pressure}
                format={(value) => toFixed(value, 2)}
              />
              {' kPa'}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section
          title="Controls"
          crtFitted
          buttons={
            <Button
              icon={data.on ? 'power-off' : 'times'}
              content={data.on ? 'On' : 'Off'}
              selected={data.on}
              onClick={() => act('power')}
            />
          }
        >
          <LabeledList>
            <LabeledList.Item label="Target Temperature">
              <NumberInput
                animated
                value={Math.round(data.target)}
                unit="K"
                width="62px"
                minValue={Math.round(data.min)}
                maxValue={Math.round(data.max)}
                step={5}
                stepPixelSize={3}
                onDrag={(value) =>
                  act('target', {
                    target: value,
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Power">
              <NumberInput
                animated
                value={Math.round(data.power)}
                unit="%"
                width="62px"
                minValue={Math.round(data.min_power)}
                maxValue={Math.round(data.max_power)}
                step={5}
                stepPixelSize={3}
                onDrag={(value) =>
                  act('set_power', {
                    target: value,
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Presets">
              <Button
                icon="fast-backward"
                disabled={data.target === data.min}
                title="Minimum temperature"
                onClick={() =>
                  act('target', {
                    target: data.min,
                  })
                }
              />
              <Button
                icon="sync"
                disabled={data.target === data.initial}
                title="Room Temperature"
                onClick={() =>
                  act('target', {
                    target: data.initial,
                  })
                }
              />
              <Button
                icon="fast-forward"
                disabled={data.target === data.max}
                title="Maximum Temperature"
                onClick={() =>
                  act('target', {
                    target: data.max,
                  })
                }
              />
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
