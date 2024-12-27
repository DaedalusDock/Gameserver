import { useBackend } from '../backend';
import { Button, Input, Section } from '../components';
import { NtosWindow } from '../layouts';

export const NtosStatus = (props) => {
  const { act, data } = useBackend();
  const { upper, lower, PC_device_theme } = data;

  return (
    <NtosWindow width={310} height={200} theme={PC_device_theme}>
      <NtosWindow.Content>
        <Section>
          <Input
            fluid
            value={upper}
            onChange={(e, value) =>
              act('stat_update', {
                position: 'upper',
                text: value,
              })
            }
          />
          <br />
          <Input
            fluid
            value={lower}
            onChange={(e, value) =>
              act('stat_update', {
                position: 'lower',
                text: value,
              })
            }
          />
          <br />
          <Button
            fluid
            onClick={() => act('stat_send')}
            content="Update Status Displays"
          />
        </Section>
      </NtosWindow.Content>
    </NtosWindow>
  );
};
