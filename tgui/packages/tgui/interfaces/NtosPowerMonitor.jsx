import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';
import { PowerMonitorContent } from './PowerMonitor';

export const NtosPowerMonitor = () => {
  const { act, data } = useBackend();
  const { PC_device_theme } = data;
  return (
    <NtosWindow width={550} height={700} theme={PC_device_theme}>
      <NtosWindow.Content>
        <PowerMonitorContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
