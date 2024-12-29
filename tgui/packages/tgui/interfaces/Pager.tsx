import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { BlockQuote, Button, Flex, Section } from '../components';
import { Window } from '../layouts';

type PagerContext = {
  messages: [];
  receiving: BooleanLike;
  the_time: string;
};

export const Pager = (_) => {
  const { act, data } = useBackend<PagerContext>();
  const { messages, receiving, the_time } = data;

  return (
    <Window width={450} height={320} title="ThinkTronic Pager">
      <Window.Content>
        <Section height="240px" title={'ThinkDOS 1.04p | ' + the_time}>
          {messages.toReversed().map((message, i) => (
            <BlockQuote key={i}>{message}</BlockQuote>
          ))}
        </Section>
        <Flex fill justify="center">
          <Flex.Item>
            <Button
              width="120px"
              selected={receiving}
              textAlign="center"
              onClick={() => act('ToggleReceiving')}
            >
              {receiving ? 'Receiving' : 'Not Receiving'}
            </Button>
          </Flex.Item>
        </Flex>
      </Window.Content>
    </Window>
  );
};
