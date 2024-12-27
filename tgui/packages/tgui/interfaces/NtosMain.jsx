import { useBackend } from '../backend';
import { Button, ColorBox, LabeledList, Section, Table } from '../components';
import { NtosWindow } from '../layouts';

export const NtosMain = (props) => {
  const { act, data } = useBackend();
  const {
    device_theme,
    show_imprint,
    programs = [],
    has_light,
    light_on,
    comp_light_color,
    removable_media = [],
    cardholder,
    login = [],
    proposed_login = [],
    disk,
    disk_name,
    disk_programs = [],
    pai,
  } = data;
  return (
    <NtosWindow
      title={
        (device_theme === 'syndicate' && 'Syndix Main Menu') ||
        'ThinkDOS Control Panel'
      }
      theme={device_theme}
      width={400}
      height={500}
    >
      <NtosWindow.Content scrollable>
        {!!has_light && (
          <Section>
            <Button
              width="168px"
              icon="lightbulb"
              selected={light_on}
              onClick={() => act('PC_toggle_light')}
            >
              Flashlight: {light_on ? 'ON' : 'OFF'}
            </Button>
            <Button ml={1} onClick={() => act('PC_light_color')}>
              Color:
              <ColorBox ml={1} color={comp_light_color} />
            </Button>
          </Section>
        )}
        {!!(cardholder && show_imprint) && (
          <Section
            title="User Login"
            buttons={
              <>
                <Button
                  icon="eject"
                  content="Eject ID"
                  disabled={!proposed_login.IDName}
                  onClick={() => act('PC_Eject_Disk', { name: 'ID' })}
                />
                <Button
                  icon="dna"
                  content="Imprint ID"
                  disabled={
                    !proposed_login.IDName ||
                    (proposed_login.IDName === login.IDName &&
                      proposed_login.IDJob === login.IDJob)
                  }
                  onClick={() => act('PC_Imprint_ID', { name: 'ID' })}
                />
              </>
            }
          >
            <LabeledList>
              <LabeledList.Item label="Identification">
                {login.IDName}{' '}
                {proposed_login.IDName && '(' + proposed_login.IDName + ')'}
              </LabeledList.Item>
              <LabeledList.Item label="Assignment">
                {login.IDJob}{' '}
                {proposed_login.IDJob && '(' + proposed_login.IDJob + ')'}
              </LabeledList.Item>
            </LabeledList>
          </Section>
        )}
        {!!removable_media.length && (
          <Section title="Media Eject">
            <Table>
              {removable_media.map((device) => (
                <Table.Row key={device}>
                  <Table.Cell>
                    <Button
                      fluid
                      color="transparent"
                      icon="eject"
                      content={device}
                      onClick={() => act('PC_Eject_Disk', { name: device })}
                    />
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Section>
        )}
        {!!pai && (
          <Section title="pAI">
            <Table>
              <Table.Row>
                <Table.Cell>
                  <Button
                    fluid
                    icon="eject"
                    color="transparent"
                    content="Eject pAI"
                    onClick={() =>
                      act('PC_Pai_Interact', {
                        option: 'eject',
                      })
                    }
                  />
                </Table.Cell>
              </Table.Row>
              <Table.Row>
                <Table.Cell>
                  <Button
                    fluid
                    icon="cat"
                    color="transparent"
                    content="Configure pAI"
                    onClick={() =>
                      act('PC_Pai_Interact', {
                        option: 'interact',
                      })
                    }
                  />
                </Table.Cell>
              </Table.Row>
            </Table>
          </Section>
        )}
        <Section title="Programs">
          <Table>
            {programs.map((program) => (
              <Table.Row key={program.name}>
                <Table.Cell fluid>
                  <Button
                    fluid
                    color={program.alert ? 'yellow' : 'transparent'}
                    icon={program.icon}
                    content={program.desc}
                    onClick={() =>
                      act('PC_runprogram', {
                        name: program.name,
                        is_disk: false,
                      })
                    }
                  />
                </Table.Cell>
                <Table.Cell collapsing fluid width="18px">
                  <Button
                    color="transparent"
                    icon="times"
                    tooltip="Close program"
                    tooltipPosition="left"
                    disabled={!!program.running}
                    onClick={() =>
                      act('PC_killprogram', {
                        name: program.name,
                      })
                    }
                  />
                </Table.Cell>
                <Table.Cell collapsing fluid width="16px">
                  <Button
                    content="A"
                    tooltip="Set Autorun"
                    tooltipPosition="left"
                    selected={!!program.autorun}
                    onClick={() =>
                      act('PC_setautorun', {
                        name: program.name,
                      })
                    }
                  />
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
        {!!disk && (
          <Section
            // pain
            title={
              disk_name
                ? disk_name.substring(0, disk_name.length - 5)
                : 'No Job Disk Inserted'
            }
            buttons={
              <Button
                icon="eject"
                content="Eject Job Disk"
                disabled={!disk_name}
                onClick={() => act('PC_Eject_Disk', { name: 'job disk' })}
              />
            }
          >
            <Table>
              {disk_programs.map((program) => (
                <Table.Row key={program.name}>
                  <Table.Cell>
                    <Button
                      fluid
                      color={program.alert ? 'yellow' : 'transparent'}
                      icon={program.icon}
                      content={program.desc}
                      onClick={() =>
                        act('PC_runprogram', {
                          name: program.name,
                          is_disk: true,
                        })
                      }
                    />
                  </Table.Cell>
                  <Table.Cell collapsing width="18px">
                    {!!program.running && (
                      <Button
                        color="transparent"
                        icon="times"
                        tooltip="Close program"
                        tooltipPosition="left"
                        onClick={() =>
                          act('PC_killprogram', {
                            name: program.name,
                          })
                        }
                      />
                    )}
                  </Table.Cell>
                  <Table.Cell collapsing width="18px">
                    <Button
                      color={program.autorun ? 'yellow' : null}
                      content="A"
                      tooltip="Set Autorun"
                      tooltipPosition="left"
                      onClick={() =>
                        act('PC_setautorun', {
                          name: program.name,
                        })
                      }
                    />
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Section>
        )}
      </NtosWindow.Content>
    </NtosWindow>
  );
};
