import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';
import { SignalerContent } from './Signaler';

export const NtosSignaler = (props) => {
  const { act, data } = useBackend();
  const { PC_device_theme } = data;
  return (
    <NtosWindow width={400} height={300} theme={PC_device_theme}>
      <NtosWindow.Content>
        <SignalerContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
