import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';
import { StationAlertConsoleContent } from './StationAlertConsole';

export const NtosStationAlertConsole = () => {
  const { act, data } = useBackend();
  const { PC_device_theme } = data;
  return (
    <NtosWindow width={335} height={587} theme={PC_device_theme}>
      <NtosWindow.Content scrollable>
        <StationAlertConsoleContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
