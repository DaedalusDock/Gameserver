import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';
import { SupermatterMonitorContent } from './SupermatterMonitor';

export const NtosSupermatterMonitor = (props) => {
  const { act, data } = useBackend();
  const { PC_device_theme } = data;
  return (
    <NtosWindow width={600} height={350} theme={PC_device_theme}>
      <NtosWindow.Content scrollable>
        <SupermatterMonitorContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
