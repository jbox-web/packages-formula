# frozen_string_literal: true

# Salt 3008 has no `gem` state: the formula declares no gem there
salt_major = command('salt-call --version').stdout[/\d{4}/].to_i

### WANTED/REQUIRED
control 'Wanted/Required gems' do
  title 'should be installed'
  only_if("Salt #{salt_major} has no gem state") { salt_major < 3008 }

  wanted = %w[
    progressbar
    minitest
  ]
  case platform[:family]
  when 'redhat'
    wanted.delete('minitest')
  end

  wanted.each do |p|
    describe gem(p) do
      it { should be_installed }
    end
  end
end

### UNWANTED
control 'Unwanted gems' do
  title 'should be uninstalled'
  only_if("Salt #{salt_major} has no gem state") { salt_major < 3008 }
  %w[
    diff-lcs
    kwalify
    kitchen-vagrant
  ].each do |p|
    describe gem(p) do
      it { should_not be_installed }
    end
  end
end
