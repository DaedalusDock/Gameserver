import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';
import { CargoContent } from './Cargo';

export const NtosCargo = (props) => {
  const { act, data } = useBackend();
  const { PC_device_theme } = data;
  return (
    <NtosWindow width={800} height={500} theme={PC_device_theme}>
      <NtosWindow.Content scrollable>
        <CargoContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
