import { useBackend } from '../backend';
import { Section, TextArea } from '../components';
import { Window } from '../layouts';

type PagerConsoleContext = {
  content: string;
};

export const PagerConsole = (_) => {
  const { act, data } = useBackend<PagerConsoleContext>();
  const { content } = data;

  return (
    <Window width={450} height={70} title="Pager Console">
      <Window.Content>
        <Section fitted>
          <TextArea
            autoFocus
            autoSelect
            dontUseTabForIndent
            selfClear
            height="2em"
            value={content}
            maxLength={42}
            onInput={(e, value) =>
              act('UpdateContent', {
                message: value,
              })
            }
            onEnter={(e, value) =>
              act('Post', {
                message: value,
              })
            }
          />
        </Section>
      </Window.Content>
    </Window>
  );
};
