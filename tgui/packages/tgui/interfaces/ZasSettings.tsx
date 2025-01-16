import { toTitleCase } from 'common/string';

import { useBackend, useLocalState } from '../backend';
import { Button, Flex, Section, Table, Tabs, Tooltip } from '../components';
import { Window } from '../layouts';

type ZasSetting = {
  category: string;
  desc: string;
  name: string;
  value: number;
};

type ZasData = {
  categories: string[];
  settings: ZasSetting[];
};

export const ZasSettings = (props) => {
  const { data } = useBackend<ZasData>();

  const [tab, setTab] = useLocalState('tab', 0);
  const settings = data.settings;
  const categories = data.categories;
  return (
    <Window title={'ZAS Settings'} width={400} height={500}>
      <Window.Content>
        <Tabs>
          {categories.map((category_name, i) => (
            <Tabs.Tab key={i} selected={i === tab} onClick={() => setTab(i)}>
              {category_name}
            </Tabs.Tab>
          ))}
        </Tabs>
        <ZasTab />
      </Window.Content>
    </Window>
  );
};

export const ZasTab = (props) => {
  const { act, data } = useBackend<ZasData>();
  const [tab, setTab] = useLocalState('tab', 0);
  const settings = data.settings;
  const selected_category = data.categories[tab];

  return (
    <Section fill height={'400px'}>
      <Flex direction="column">
        {Object.values(settings).map(
          (setting, i) =>
            setting.category === selected_category && (
              <Flex.Item
                key={i}
                className="candystripe"
                label={toTitleCase(setting.name)}
              >
                <Table height="2em">
                  <Table.Row key={setting.name}>
                    <Table.Cell pl="8px" width="60%">
                      <Tooltip content={setting.desc}>
                        <span>{setting.name}</span>
                      </Tooltip>
                    </Table.Cell>
                    <Table.Cell textAlign="left">
                      {setting.value.toString()}
                    </Table.Cell>
                    <Table.Cell textAlign="right">
                      <Button
                        onClick={() =>
                          act('change_var', {
                            var_name: getKeyByValue(settings, setting),
                            var_human_name: setting.name,
                          })
                        }
                      >
                        Change
                      </Button>
                    </Table.Cell>
                  </Table.Row>
                </Table>
              </Flex.Item>
            ),
        )}
      </Flex>
    </Section>
  );
};

const getKeyByValue = (obj, value) =>
  Object.keys(obj).find((key) => obj[key] === value);
