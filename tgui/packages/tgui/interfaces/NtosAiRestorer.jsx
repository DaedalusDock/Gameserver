import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';
import { AiRestorerContent } from './AiRestorer';

export const NtosAiRestorer = () => {
  const { act, data } = useBackend();
  const { PC_device_theme } = data;
  return (
    <NtosWindow width={370} height={400} theme={PC_device_theme}>
      <NtosWindow.Content scrollable>
        <AiRestorerContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
