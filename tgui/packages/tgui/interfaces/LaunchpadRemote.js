import { useBackend } from '../backend';
import { NoticeBox } from '../components';
import { Window } from '../layouts';
import { LaunchpadControl } from './LaunchpadConsole';

export const LaunchpadRemote = (props) => {
  const { data } = useBackend();
  const { has_pad, pad_closed } = data;
  return (
    <Window
      title="Briefcase Launchpad Remote"
      width={300}
      height={240}
      theme="syndicate">
      <Window.Content>
        {(!has_pad && <NoticeBox>No Launchpad Connected</NoticeBox>) ||
          (pad_closed && <NoticeBox>Launchpad Closed</NoticeBox>) || (
            <LaunchpadControl topLevel />
          )}
      </Window.Content>
    </Window>
  );
};
